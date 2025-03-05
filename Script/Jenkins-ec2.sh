#!/bin/bash
apt update
apt install openjdk-17-jre -y
apt update
apt install curl -y
apt update
apt install python3 -y
apt update
wget -O /usr/share/keyrings/jenkins-keyring.asc https://pkg.jenkins.io/debian/jenkins.io-2023.key
echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc]" https://pkg.jenkins.io/debian binary/ | sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null
apt-get update
apt-get install jenkins -y
apt-get update
curl -L https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m) -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
apt install postgresql postgresql-contrib -y
sudo apt -y install unzip
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
apt update
apt-get install docker.io -y
sudo systemctl resatrt docker
sudo systemctl enable docker
sudo usermod -aG $USER
newgrp docker
apt update
