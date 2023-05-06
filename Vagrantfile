# -*- mode: ruby -*-
# vi: set ft=ruby :


# modes: containerd/flanner, containerd/calico, cri-o/flannel, cri-o/calico

ENV['VAGRANT_NO_PARALLEL'] = 'yes'
VM_BOX           = "bento/ubuntu-22.04"
ROOT_PW          = "kubeadm"
CONTAINER_ENGINE = "containerd"           # containerd / cri-o
CNI              = "calico"              # calico / flannel
WORKER_NODES     = 2


Vagrant.configure(2) do |config|
  #config.vm.provision "file", source: "bootstrap.sh", destination: "~/bootstrap.sh"
  config.vm.provision "shell", path: "bootstrap.sh", args: [ ROOT_PW, CONTAINER_ENGINE ]

  # Kubernetes Master Server
  config.vm.define "master" do |master|
    master.vm.box      = VM_BOX
    master.vm.hostname = "master"
    master.vm.network "private_network", ip: "172.42.42.100"
    master.vm.provider "virtualbox" do |v|
      v.name   = "master"
      v.memory = 2048
      v.cpus   = 2
    end
    #master.vm.provision "file", source: "master_bootstrap.sh", destination: "~/master_bootstrap.sh"
    master.vm.provision "shell", path: "master_bootstrap.sh", args: [ CNI, CONTAINER_ENGINE ]
  end


  # Kubernetes Worker Nodes
  (1..WORKER_NODES).each do |i|
    config.vm.define "worker#{i}" do |workernode|
      workernode.vm.box      = VM_BOX
      workernode.vm.hostname = "worker#{i}"
      workernode.vm.network "private_network", ip: "172.42.42.10#{i}"
      workernode.vm.provider "virtualbox" do |v|
        v.name   = "worker#{i}"
        v.memory = 1024
        v.cpus   = 2 
      end
      #workernode.vm.provision "file", source: "worker_bootstrap.sh", destination: "~/worker_bootstrap.sh"
      workernode.vm.provision "shell", path: "worker_bootstrap.sh", args: ROOT_PW
    end
  end
end
