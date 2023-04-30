#!/bin/bash

# Initialize Kubernetes
echo "[m0] Initialize Kubernetes Cluster with kubeadm"
if [[ ${2} == "cri-o" ]]; then
  ARG="--cri-socket=unix:///var/run/crio/crio.sock"
fi

if [[ ${1} == "flannel" ]]; then
  kubeadm init --apiserver-advertise-address=172.42.42.100 --pod-network-cidr=10.244.0.0/16 ${ARG} >> /root/kubeinit.log
elif [[ ${1} == "calico" ]]; then
  kubeadm init --apiserver-advertise-address=172.42.42.100 --pod-network-cidr=192.168.0.0/16 ${ARG} >> /root/kubeinit.log
fi

# Copy Kube admin config
echo "[m1] Copy kube admin config to Vagrant user .kube directory"
mkdir /home/vagrant/.kube
cp /etc/kubernetes/admin.conf /home/vagrant/.kube/config
chown -R vagrant:vagrant /home/vagrant/.kube


if [[ ${1} == "calico" ]]; then
  # Deploy calico CNI
  echo "[m2] Deploy calico network plugin"
  su - vagrant -c "kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.25.1/manifests/tigera-operator.yaml >/dev/null 2>&1"
  su - vagrant -c "kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.25.1/manifests/custom-resources.yaml >/dev/null 2>&1"
elif [[ ${1} == "flannel" ]]; then
  echo "[m2] Deploy flannel network plugin"
  sudo mkdir -p /opt/cni/bin
  curl -O -L https://github.com/containernetworking/plugins/releases/download/v1.2.0/cni-plugins-linux-amd64-v1.2.0.tgz
  sudo tar -C /opt/cni/bin -xzf cni-plugins-linux-amd64-v1.2.0.tgz
  su - vagrant -c "kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml > flannel_install.log 2>&1"
  echo "flannel apply: $?"
fi


# Generate Cluster join command
echo "[m3] Generate and save cluster join command to /root/joincluster.sh"
kubeadm token create --print-join-command > /root/joincluster.sh
