#!/bin/bash
sudo apt update
sudo apt install openjdk-17-jre -y
sudo apt update
sudo apt install curl -y
sudo apt update
sudo apt install python3 -y
sudo apt update
sudo wget -O /usr/share/keyrings/jenkins-keyring.asc https://pkg.jenkins.io/debian/jenkins.io-2023.key
echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc]" https://pkg.jenkins.io/debian binary/ | sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null
sudo apt-get update
sudo apt-get install jenkins -y
sudo apt-get update
curl -L https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m) -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
sudo apt install postgresql postgresql-contrib -y
sudo apt -y install unzip
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
sudo apt update
sudo apt-get install docker.io -y
sudo systemctl restart docker
sudo systemctl enable docker
sudo usermod -aG $USER
newgrp docker
sudo apt update
