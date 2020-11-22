#!/bin/bash -xe
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

sysctl -w net.core.somaxconn=1024
echo 'net.core.somaxconn=1024' >> /etc/sysctl.conf
amazon-linux-extras enable epel
yum update -q -y
yum install -q -y squid squidGuard ca-certificates epel-release
update-ca-trust force-enable

wget -q https://s3.us-east-1.amazonaws.com/amazoncloudwatch-agent-us-east-1/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm
rpm --quiet -U ./amazon-cloudwatch-agent.rpm || true
rm -f ./amazon-cloudwatch-agent.rpm
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c ssm:AmazonCloudWatch-trivialsec-proxy

mkdir -p /etc/squid/ssl /etc/squid/old/ ~/.ssh

aws s3 cp --only-show-errors s3://cloudformation-trivialsec/deploy-keys/${PRIV_KEY_NAME}.pem ~/.ssh/${PRIV_KEY_NAME}.pem
chmod 400 ~/.ssh/${PRIV_KEY_NAME}.pem
eval $(ssh-agent -s)
ssh-add ~/.ssh/${PRIV_KEY_NAME}.pem
ssh-keyscan -H proxy.trivialsec.com >> ~/.ssh/known_hosts

cd /etc/squid/ssl
openssl genrsa -out squid.key 4096
openssl req -new -key squid.key -out squid.csr -subj "/C=XX/ST=XX/L=squid/O=squid/CN=squid"
openssl x509 -req -days 3650 -in squid.csr -signkey squid.key -out squid.crt
cat squid.key squid.crt >> squid.pem

iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 3129
iptables -t nat -A PREROUTING -p tcp --dport 443 -j REDIRECT --to-port 3130

cp /etc/squid/* /etc/squid/old/
aws s3 cp --only-show-errors s3://cloudformation-trivialsec/deploy-packages/allowed-sites.txt /etc/squid/allowed-sites.txt
aws s3 cp --only-show-errors s3://cloudformation-trivialsec/deploy-packages/squid.conf /etc/squid/squid.conf
squid -k parse && squid -k reconfigure || (cp /etc/squid/old/* /etc/squid/; exit 1)

touch /etc/squid/passwd
chown squid: /etc/squid/passwd

systemctl enable squid
systemctl start squid
systemctl status squid

echo $(date +'%F') > /home/ec2-user/.deployed