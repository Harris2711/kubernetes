#!/bin/bash

sleep 2m

#swapoff
swapoff -a

apt-get install unzip -y

curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install


#Update sysctl settings for Kubernetes networking
cat >>/etc/sysctl.d/kubernetes.conf<<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sysctl --system

#install docker
sudo apt-get update
sudo apt-get install \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg


echo \
"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
$(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-compose-plugin -y 


#configure Containerd 

sudo mv etc/containerd/config.toml etc/containerd/config.toml.orig
containerd config default | sudo tee /etc/containerd/config.toml

sudo sed -i 's/SystemdCgroup \= false/SystemdCgroup \= true/g' /etc/containerd/config.toml

#install cni plugin

wget https://github.com/containernetworking/plugins/releases/download/v1.1.1/cni-plugins-linux-amd64-v1.1.1.tgz

mkdir -p /opt/cni/bin
tar Cxzvf /opt/cni/bin cni-plugins-linux-amd64-v1.1.1.tgz

sudo systemctl restart containerd

aws ec2 describe-instances --filters Name=tag:haproxy,Values=lb --region ap-south-1   --query 'Reservations[*].Instances[*][PrivateIpAddress]' --output text > ip.txt

haproxyip=$(cat ip.txt)



#install kubelet kubeadm kubectl

sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl

sudo curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg


echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list


sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

#intialize kubeadm
kubeadm init --control-plane-endpoint $haproxyip --pod-network-cidr=192.168.0.0/16 --upload-certs | tee -a output.txt


sed -n -e 71,73p output.txt > 1.txt


sed -n -e 77p -e 78p output.txt > 2.txt


token=$(cat 1.txt)

cat >>token.json<<EOF
[
  {
    "Key": "string",
    "Value": "$token"
  }
  ...
]
EOF

token2=$(cat 2.txt)

cat >>token2.json<<EOF
[
  {
    "Key": "string",
    "Value": "$token2"
  }
  ...
]
EOF

aws secretsmanager create-secret --name mastertoken --secret-string file://token.json

aws secretsmanager create-secret --name workertoken --secret-string file://token2.json


mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
