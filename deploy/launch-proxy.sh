#!/bin/bash -x

if [[ $EUID -eq 0 ]]; then
   echo -e "This script must not be run as root" 
   exit 1
fi
if [[ ! -d scripts ]]; then
    echo -e "Run this from the project root directory"
    exit 0
fi

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
    while ! [ $(ssh -o 'StrictHostKeyChecking no' -4 -J ec2-user@proxy.trivialsec.com ec2-user@${privateIp} 'echo `[ -f .deployed ]` $?') -eq 0 ]
    do
        sleep 2
    done
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