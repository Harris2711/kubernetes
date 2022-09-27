#!/bin/bash

sudo -s

apt-get install unzip -y

curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install


#swapoff
swapoff -a

cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# sysctl params required by setup, params persist across reboots
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

# Apply sysctl params without reboot
sudo sysctl --system


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
sudo apt-get install containerd.io -y 


#configure Containerd 

sudo mv etc/containerd/config.toml etc/containerd/config.toml.orig
containerd config default | sudo tee /etc/containerd/config.toml

sudo sed -i 's/SystemdCgroup \= false/SystemdCgroup \= true/g' /etc/containerd/config.toml

#install cni plugin

wget https://github.com/containernetworking/plugins/releases/download/v1.1.1/cni-plugins-linux-amd64-v1.1.1.tgz

mkdir -p /opt/cni/bin
tar Cxzvf /opt/cni/bin cni-plugins-linux-amd64-v1.1.1.tgz

sudo systemctl restart containerd


#install kubelet kubeadm kubectl

sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl

sudo curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg


echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list


sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

#install git
apt-get install git -y

#clone privatekey
git clone https://github.com/Harris2711/privatekey.git
cd privatekey/
cat privkey.pem | base64 --decode > key.pem
chmod 400 key.pem


ssh -o "StrictHostKeyChecking no" -i key.pem ubuntu@172.31.35.187 sudo -- "sh -c 'git clone https://github.com/Harris2711/privatekey.git'"

ssh -o "StrictHostKeyChecking no" -i key.pem ubuntu@172.31.35.187 sudo -- "sh -c 'chmod +x /home/ubuntu/privatekey/mastertoken.sh'"

ssh -o "StrictHostKeyChecking no" -i key.pem ubuntu@172.31.35.187 sudo -- "sh -c '/home/ubuntu/privatekey/mastertoken.sh'"


aws secretsmanager get-secret-value --secret-id secretmaster | grep "SecretString" | sed 's/"SecretString"//' | sed '1s/://' | sed 's/"//g' | sed 's/,//' | sed 's/.$//' | sed 's/.$//' > token.sh

chmod +x token.sh
./token.sh
