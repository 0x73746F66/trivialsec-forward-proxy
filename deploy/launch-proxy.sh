#!/bin/bash -x

if [[ $EUID -eq 0 ]]; then
   echo -e "This script must not be run as root" 
   exit 1
fi
if [[ ! -d deploy ]]; then
    echo -e "Run this from the project root directory"
    exit 0
fi

readonly proxy_host=proxy.trivialsec.com

function setup_ssh() {
    local ip_address=$1
    mkdir -p ~/.ssh
    ssh-keygen -R ${proxy_host}
    aws s3 cp --only-show-errors s3://trivialsec-assets/deploy-keys/${PRIV_KEY_NAME}.pem ~/.ssh/${PRIV_KEY_NAME}.pem
    chmod 400 ~/.ssh/${PRIV_KEY_NAME}.pem
    ssh-keyscan -H ${proxy_host} >> ~/.ssh/known_hosts
    cat > ~/.ssh/config << EOF
Host proxy
  CheckHostIP no
  StrictHostKeyChecking no
  HostName ${proxy_host}
  IdentityFile ~/.ssh/${PRIV_KEY_NAME}.pem
  User ec2-user

Host ec2
  CheckHostIP no
  StrictHostKeyChecking no
  Hostname ${ip_address}
  IdentityFile ~/.ssh/${PRIV_KEY_NAME}.pem
  User ec2-user
  ProxyCommand ssh -W %h:%p proxy

EOF
}
readonly existingInstanceId=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=Proxy" --instance-ids $(aws ec2 describe-instances --filters "Name=instance-state-name,Values=running" --query 'Reservations[].Instances[].InstanceId' --output text) --query 'Reservations[].Instances[].InstanceId' --output text)

instanceId=$(aws ec2 run-instances \
    --associate-public-ip-address \
    --image-id ${BASE_AMI} \
    --count 1 \
    --instance-type ${DEFAULT_INSTANCE_TYPE} \
    --key-name ${PRIV_KEY_NAME} \
    --subnet-id ${SUBNET_ID} \
    --security-group-ids ${SECURITY_GROUP_IDS} \
    --iam-instance-profile Name=${IAM_INSTANCE_PROFILE} \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=Proxy},{Key=proxy,Value=production},{Key=cost-center,Value=${COST_CENTER}}]" "ResourceType=volume,Tags=[{Key=cost-center,Value=${COST_CENTER}}]" \
    --user-data file://deploy/user-data/bake-proxy.sh \
    --query 'Instances[].InstanceId' --output text)

if [[ ${instanceId} == i-* ]]; then
    aws ec2 wait instance-running --instance-ids ${instanceId}
    aws ec2 wait instance-status-ok --instance-ids ${instanceId}
    privateIp=$(aws ec2 describe-instances --instance-ids ${instanceId} --query 'Reservations[].Instances[].PrivateIpAddress' --output text)
    setup_ssh ${privateIp}
    while ! [ $(ssh -4 ec2 'echo `[ -f .deployed ]` $?' || echo 1) -eq 0 ]
    do
        sleep 2
    done
    scp -4 ec2:/var/log/user-data.log .
    cat user-data.log
    if [[ ! -z "${existingInstanceId}" ]] && [[ ${existingInstanceId} == i-* ]]; then
        aws ec2 terminate-instances --instance-ids ${existingInstanceId}
    fi
    IPv4=$(aws ec2 describe-instances --instance-ids ${instanceId} --query 'Reservations[].Instances[].PrivateIpAddress' --output text)
    IPv6=$(aws ec2 describe-instances --instance-ids ${instanceId} --query 'Reservations[].Instances[].NetworkInterfaces[].Ipv6Addresses[].Ipv6Address' --output text)
    if [[ ! -z "$IPv4" ]] && [[ ! -z "$IPv6" ]]; then
        cat << EOF >${ROUTE53_JSON}
{"Changes": [{
    "Action": "UPSERT",
    "ResourceRecordSet": {
        "Name": "proxy.trivialsec.local",
        "Type": "A",
        "TTL": 300,
        "ResourceRecords": [{"Value": "${IPv4}"}]
    }
}, {
    "Action": "UPSERT",
    "ResourceRecordSet": {
        "Name": "proxy.trivialsec.local",
        "Type": "AAAA",
        "TTL": 300,
        "ResourceRecords": [{"Value": "${IPv6}"}]
    }
}]}
EOF
        aws route53 change-resource-record-sets \
            --hosted-zone-id ${HOSTED_ZONE_ID} \
            --change-batch file://${ROUTE53_JSON}
    fi
    if [[ ! -z "${EIP_ALLOCATION_ID}" ]]; then
        aws ec2 associate-address --instance-id ${instanceId} --allocation-id ${EIP_ALLOCATION_ID} --allow-reassociation
    fi
fi

echo completed