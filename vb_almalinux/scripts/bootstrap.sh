#!/bin/bash

IP=$1
K8S=$2

echo "[TASK 0] install dependecy"
whoami
yum install epel-release -y
yum install yum-utils nano git wget curl jq -y

echo "[TASK 1] sync time"
yum install ntp -y -q
systemctl start ntpd
systemctl enable ntpd

# Install docker from Docker-ce repository
echo "[TASK 2] Install container engine"
yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo > /dev/null 2>&1
yum install -y -q device-mapper-persistent-data lvm2 iproute-tc iscsi-initiator-utils containerd sudo
modprobe iscsi_tcp
echo "iscsi_tcp" >/etc/modules-load.d/iscsi-tcp.conf
systemctl enable --now iscsid >/dev/null 2>&1

# Enable containerd service
echo "[TASK 3] Enable and start docker servicecontainerd"
sudo mkdir -p /etc/containerd
sudo containerd config default > /etc/containerd/config.toml
sed -i 's/\[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options\]/\[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options\]\n            SystemdCgroup = true/' /etc/containerd/config.toml
systemctl enable --now containerd >/dev/null 2>&1
echo "runtime-endpoint: unix:///run/containerd/containerd.sock" > /etc/crictl.yaml
cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF
sudo modprobe overlay
sudo modprobe br_netfilter

# Disable SELinux
echo "[TASK 4] Disable SELinux"
setenforce 0
sed -i --follow-symlinks 's/^SELINUX=enforcing/SELINUX=disabled/' /etc/sysconfig/selinux

# Stop and disable firewalld
echo "[TASK 5] Stop and Disable firewalld"
systemctl disable firewalld >/dev/null 2>&1
systemctl stop firewalld >/dev/null 2>&1

# Add sysctl settings
echo "[TASK 6] Add sysctl settings"
cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
#
# protectKernelDefaults
#
kernel.keys.root_maxbytes           = 25000000
kernel.keys.root_maxkeys            = 1000000
kernel.panic                        = 10
kernel.panic_on_oops                = 1
vm.overcommit_memory                = 1
vm.panic_on_oom                     = 0
EOF
sysctl --system >/dev/null 2>&1

# Disable swap
echo "[TASK 7] Disable and turn off SWAP"
sed -i '/swap/d' /etc/fstab
swapoff -a

# Add yum repo file for Kubernetes
echo "[TASK 8] Add yum repo file for kubernetes"
cat >>/etc/yum.repos.d/kubernetes.repo<<EOF
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg
        https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF

# Install Kubernetes
echo "[TASK 9] Install Kubernetes (kubeadm, kubelet and kubectl)"
yum remove -y -q kubeadm kubelet kubectl >/dev/null 2>&1
yum install -y -q kubeadm-$K8S-0 kubelet-$K8S-0 kubectl-$K8S-0 >/dev/null 2>&1

# Start and Enable kubelet service
echo "[TASK 10] Enable and start kubelet service"
echo KUBELET_EXTRA_ARGS=\"--node-ip=$IP --container-runtime=remote --container-runtime-endpoint=/run/containerd/containerd.sock\" > /etc/sysconfig/kubelet
systemctl enable kubelet >/dev/null 2>&1
systemctl start kubelet >/dev/null 2>&1

# Enable ssh password authentication
echo "[TASK 12] Enable ssh password authentication"
sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
systemctl reload sshd

# Set Root password
echo "[TASK 13] Set root password"
echo "kubeadmin" | passwd --stdin root >/dev/null 2>&1

# download images
echo "[TASK 14] Download Docker Images"
kubeadm config images pull --kubernetes-version v$K8S

echo "[ DONE ]"
