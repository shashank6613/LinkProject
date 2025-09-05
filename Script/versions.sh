#!/bin/bash
set -e

echo "----------------------------------------"
echo " Checking Installed Software Versions"
echo "----------------------------------------"

echo -n "Java (OpenJDK): "
java -version 2>&1 | head -n 1

echo -n "Curl: "
curl --version | head -n 1

echo -n "Python3: "
python3 --version

echo -n "Jenkins: "
jenkins_version=$(dpkg -s jenkins 2>/dev/null | grep '^Version:' | awk '{print $2}')
echo "${jenkins_version:-Not Installed}"

echo -n "PostgreSQL: "
psql --version || echo "Not Installed"

echo -n "Docker: "
docker --version || echo "Not Installed"

echo -n "AWS CLI: "
aws --version 2>&1 | head -n 1 || echo "Not Installed"

echo -n "kubectl: "
if command -v kubectl &>/dev/null; then
    kubectl version --client=true 2>/dev/null | grep -E "Client Version|Kustomize Version"
else
    echo "Not Installed"
fi

echo -n "eksctl: "
eksctl version || echo "Not Installed"

echo -n "Node.js: "
node -v || echo "Not Installed"

echo -n "NPM: "
npm -v || echo "Not Installed"

echo "----------------------------------------"
echo " Version check completed."
