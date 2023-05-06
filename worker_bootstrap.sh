#!/bin/bash

# Join worker nodes to the Kubernetes cluster
echo "[w0] Join node to Kubernetes Cluster"
apt install -y sshpass >/dev/null 2>&1
sshpass -p "${1}" scp -o StrictHostKeyChecking=no master:/root/joincluster.sh /root/joincluster.sh
bash /root/joincluster.sh >/dev/null 2>&1
