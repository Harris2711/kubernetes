#!/bin/bash

apt-get update -y
apt install -y haproxy

apt-get install unzip -y
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

aws ec2 describe-instances --filters Name=tag:Name,Values=master --region ap-south-1   --query 'Reservations[*].Instances[*][PrivateIpAddress]' --output text > ip.txt

cat ip.txt | head -n +1 > master1.txt
cat ip.txt | sed -n '2p' > master2.txt
cat ip.txt | tail -n -1 > master3.txt

master1=$(cat master1.txt)
master2=$(cat master2.txt)
master3=$(cat master3.txt)


cat >>/etc/haproxy/haproxy.cfg<<EOF
frontend kubernetes-frontend
    bind $(hostname -i):6443
    mode tcp
    option tcplog
    default_backend kubernetes-backend

backend kubernetes-backend
    mode tcp
    option tcp-check
    balance roundrobin
    server master1 $master1:6443 check fall 3 rise 2
    server master2 $master2:6443 check fall 3 rise 2
    server master3 $master3:6443 check fall 3 rise 2
EOF

systemctl restart haproxy