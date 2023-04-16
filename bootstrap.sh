#!/bin/bash

function hosts_file {
  # Update hosts file
  echo "[TASK 1] Update /etc/hosts file"
  echo "172.42.42.100 kmaster.example.com kmaster" >> /etc/hosts
  echo "172.42.42.101 kworker1.example.com kworker1" >> /etc/hosts
  echo "172.42.42.102 kworker2.example.com kworker2" >> /etc/hosts
  }

function kernel_modules {
  # Update modules
  echo "[TASK 2] Configure kernel modules"
  sudo modprobe overlay
  sudo modprobe br_netfilter
  echo overlay >> /etc/modules-load.d/kubernetes.conf
  echo br_netfilter >> /etc/modules-load.d/kubernetes.conf
} 

function install_containerd {
  echo "[TASK 3] Install containerd engine"
  apt install curl -y
  containerd_tar=containerd-1.6.8-linux-amd64.tar.gz
  cni_plugin_tar=cni-plugins-linux-amd64-v1.1.1.tgz
  wget https://github.com/containerd/containerd/releases/download/v1.6.8/${containerd_tar}
  wget https://github.com/opencontainers/runc/releases/download/v1.1.3/runc.amd64
  wget https://github.com/containernetworking/plugins/releases/download/v1.1.1/${cni_plugin_tar}
  tar Cxzvf /usr/local ${containerd_tar} && rm -f ${containerd_tar}
  install -m 755 runc.amd64 /usr/local/sbin/runc
  mkdir -p /opt/cni/bin
  tar Cxzvf /opt/cni/bin ${cni_plugin_tar} && rm -f ${cni_plugin_tar}
  mkdir /etc/containerd
  containerd config default | tee /etc/containerd/config.toml
  sed -i 's/SystemdCgroup \= false/SystemdCgroup \= true/g' /etc/containerd/config.toml
}

function enable_containerd {
  echo "[TASK 4] Enable and start containerd service"
  # Enable containerd service
  curl -L https://raw.githubusercontent.com/containerd/containerd/main/containerd.service -o /etc/systemd/system/containerd.service
  systemctl daemon-reload
  systemctl enable --now containerd
}

function install_crio {
  export OS=xUbuntu_22.04
  export VERSION=1.26
  # Adding CRI-O repository for Ubuntu systems
  echo "deb [signed-by=/usr/share/keyrings/libcontainers-archive-keyring.gpg] https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/$OS/ /" > /etc/apt/sources.list.d/devel:kubic:libcontainers:stable.list
  echo "deb [signed-by=/usr/share/keyrings/libcontainers-crio-archive-keyring.gpg] https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable:/cri-o:/$VERSION/$OS/ /" > /etc/apt/sources.list.d/devel:kubic:libcontainers:stable:cri-o:$VERSION.list
  mkdir -p /usr/share/keyrings
  curl -L https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/$OS/Release.key | gpg --dearmor -o /usr/share/keyrings/libcontainers-archive-keyring.gpg
  curl -L https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable:/cri-o:/$VERSION/$OS/Release.key | gpg --dearmor -o /usr/share/keyrings/libcontainers-crio-archive-keyring.gpg
  apt update -y
  apt install -y cri-o cri-o-runc cri-tools
  systemctl enable crio.service
  systemctl start crio.service
}

function sysctl_settings {
  # Add sysctl settings
  echo "[TASK 5] Add sysctl settings"
  echo "net.bridge.bridge-nf-call-ip6tables = 1" >> /etc/sysctl.d/kubernetes.conf
  echo "net.bridge.bridge-nf-call-iptables  = 1" >> /etc/sysctl.d/kubernetes.conf
  echo "net.ipv4.ip_forward                 = 1" >> /etc/sysctl.d/kubernetes.conf
  sysctl --system >/dev/null 2>&1
}


function disable_swap {
  # Disable swap
  echo "[TASK 6] Disable and turn off SWAP"
  sed -i '/swap/d' /etc/fstab
  swapoff -a
}


function ufw_config {
  echo "[TASK 7] Open up ports for kubernetes"
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
  ufw allow 2379/tcp
  ufw allow 8080/tcp
}

function apt_transport_https {
  # Install apt-transport-https pkg
  echo "[TASK 8] Installing apt-transport-https pkg"
  apt update && apt-get install -y apt-transport-https net-tools vim
  curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
}

function install_kubernetes {
  # Add he kubernetes sources list into the sources.list directory
  echo "deb https://apt.kubernetes.io/ kubernetes-xenial main">> /etc/apt/sources.list.d/kubernetes.list
  ls -ltr /etc/apt/sources.list.d/kubernetes.list
  apt update -y

  # Install Kubernetes
  echo "[TASK 9] Install Kubernetes kubeadm, kubelet and kubectl"
  apt install -y kubelet kubeadm kubectl

  # Start and Enable kubelet service
  echo "[TASK 10] Enable and start kubelet service"
  systemctl enable kubelet >/dev/null 2>&1
  systemctl start kubelet >/dev/null 2>&1
}

function setup_root {  
  # Enable ssh password authentication
  echo "[TASK 11] Enable ssh password authentication"
  sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
  systemctl restart sshd

  # Set Root password
  echo "[TASK 12] Set root password"
  echo -e "kubeadmin\nkubeadmin" | passwd root
  #echo "kubeadmin" | passwd --stdin root >/dev/null 2>&1
}


set -e 
hosts_file
kernel_modules
install_containerd
enable_containerd
install_crio
sysctl_settings
disable_swap
ufw_config
apt_transport_https
install_kubernetes
setup_root

