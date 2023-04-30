#!/bin/bash


function turn_off_swap {
  echo "[0] Turn off swap"
  sed -i '/swap/d' /etc/fstab
  swapoff -a
}


function hosts_file {
  # Update hosts file
  echo "[1] Update /etc/hosts file"
  echo "172.42.42.100 master master" >> /etc/hosts
  echo "172.42.42.101 worker1 worker1" >> /etc/hosts
  echo "172.42.42.102 worker2 worker2" >> /etc/hosts
  }


function kernel_modules {
  # Update modules
  echo "[2] Configure kernel modules"
  modprobe overlay
  modprobe br_netfilter
  echo overlay >> /etc/modules-load.d/kubernetes.conf
  echo br_netfilter >> /etc/modules-load.d/kubernetes.conf
} 


function ufw_config {
  echo "[3] Open up ports for kubernetes"
  # Opening ports for Control Plane
  ufw allow 6443/tcp
  ufw allow 2379:2380/tcp
  ufw allow 10250/tcp
  ufw allow 10259/tcp
  ufw allow 10257/tcp
  ufw allow 30000:32767/tcp
  # Opening ports for Calico CNI
  ufw allow 179/tcp
  ufw allow 4789/udp
  ufw allow 4789/tcp
  ufw allow 8080/tcp
  ufw allow 80/tcp
}


function install_containerd {
  echo "[4] Install containerd engine"
  apt update -qq >/dev/null 2>&1
  apt install -qq -y ca-certificates curl gnupg lsb-release >/dev/null 2>&1
  mkdir -p /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg >/dev/null 2>&1
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
  apt update -qq >/dev/null 2>&1
  apt install -qq -y containerd.io >/dev/null 2>&1
  containerd config default > /etc/containerd/config.toml
  sed -i 's/SystemdCgroup \= false/SystemdCgroup \= true/g' /etc/containerd/config.toml
  systemctl restart containerd
  systemctl enable containerd >/dev/null 2>&1
}


function install_crio {
  echo "[4] Install cri-o engine"
  export OS=xUbuntu_22.04
  export VERSION=1.26
  # Adding CRI-O repository for Ubuntu systems
  echo "deb [signed-by=/usr/share/keyrings/libcontainers-archive-keyring.gpg] https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/$OS/ /" > /etc/apt/sources.list.d/devel:kubic:libcontainers:stable.list
  echo "deb [signed-by=/usr/share/keyrings/libcontainers-crio-archive-keyring.gpg] https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable:/cri-o:/$VERSION/$OS/ /" > /etc/apt/sources.list.d/devel:kubic:libcontainers:stable:cri-o:$VERSION.list
  mkdir -p /usr/share/keyrings
  curl -L https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/$OS/Release.key | gpg --dearmor -o /usr/share/keyrings/libcontainers-archive-keyring.gpg
  curl -L https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable:/cri-o:/$VERSION/$OS/Release.key | gpg --dearmor -o /usr/share/keyrings/libcontainers-crio-archive-keyring.gpg
  apt update && apt install -y cri-o cri-o-runc cri-tools
cat >>/etc/crio/crio.conf.d/02-cgroup-manager.conf<<EOF
[crio.runtime]
conmon_cgroup = "pod"
cgroup_manager = "cgroupfs"
EOF
  systemctl daemon-reload
  systemctl enable --now crio
}

function sysctl_settings {
  # Add sysctl settings
  echo "[5] Add sysctl settings"
  echo "net.bridge.bridge-nf-call-ip6tables = 1" >> /etc/sysctl.d/kubernetes.conf
  echo "net.bridge.bridge-nf-call-iptables  = 1" >> /etc/sysctl.d/kubernetes.conf
  echo "net.ipv4.ip_forward                 = 1" >> /etc/sysctl.d/kubernetes.conf
  sysctl --system >/dev/null 2>&1
}


function apt_transport_https {
  # Install apt-transport-https pkg
  echo "[6] Installing apt-transport-https pkg"
  curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add - >/dev/null 2>&1
  apt-add-repository "deb http://apt.kubernetes.io/ kubernetes-xenial main" >/dev/null 2>&1
}


function install_kubernetes {
  # Install Kubernetes
  echo "[7] Install Kubernetes kubeadm, kubelet and kubectl"
  apt install -qq -y kubeadm=1.26.0-00 kubelet=1.26.0-00 kubectl=1.26.0-00 >/dev/null 2>&1
  systemctl enable kubelet >/dev/null 2>&1
  systemctl start kubelet >/dev/null 2>&1
}


function setup_root {
  # Enable ssh password authentication
  echo "[8] Enable ssh password authentication"
  sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
  systemctl restart sshd
  echo -e "${1}\n${1}" | passwd root
}


set -e 
turn_off_swap
hosts_file
kernel_modules
ufw_config
if [[ ${2} == "containerd" ]]; then
  install_containerd
elif [[ ${2} == "cri-o" ]]; then
  install_crio 
fi
sysctl_settings
apt_transport_https
install_kubernetes
setup_root ${1}
