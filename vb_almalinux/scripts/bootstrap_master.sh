#!/bin/bash

IP=$1
K8SV=$2
CNI=$3

# reset kubeadm
#echo "[TASK 0] Reset kubeadm"
#kubeadm reset -f > /dev/null 2>&1
#rm -f /vagrant/admin.conf > /dev/null 2>&1
#rm -rf /home/vagrant/.kube > /dev/null 2>&1
#rm -rf /root/.kube > /dev/null 2>&1

# Initialize Kubernetes
echo "[TASK 1] Initialize Kubernetes Cluster"
kubeadm init --kubernetes-version=v$K8SV --apiserver-advertise-address=$IP --pod-network-cidr=10.244.0.0/16 --ignore-preflight-errors=NumCPU >> /root/kubeinit.log 2>/dev/null

# Copy Kube admin config
echo "[TASK 3] Copy kube admin config to Vagrant user .kube directory"
mkdir /home/vagrant/.kube
cp /etc/kubernetes/admin.conf /home/vagrant/.kube/config
chown -R vagrant:vagrant /home/vagrant/.kube
mkdir /root/.kube
cp /etc/kubernetes/admin.conf /root/.kube/config
rm -f /vagrant/admin.conf
cat /etc/kubernetes/admin.conf > /vagrant/config

if [ "$CNI" == "calico" ]; then
# Deploy Calico network
echo "[TASK 4] Deploy Calico network"
#kubectl create -f https://docs.projectcalico.org/v3.12/manifests/calico.yaml
#kubectl create -f /vagrant/scripts/calico3-12.yaml
kubectl create -f https://docs.projectcalico.org/manifests/tigera-operator.yaml
kubectl create -f /vagrant/scripts/custom-resources.yaml
else
echo "[TASK 4] Deploy flannel network"
# kubectl create -f /vagrant/scripts/kube-flannel.yml
fi

# Generate Cluster join command
echo "[TASK 5] Generate and save cluster join command to /joincluster.sh"
kubeadm token create --print-join-command > /vagrant/joincluster.sh

# allow provision on master
echo "[TASK 6] Allow provision on master"
kubectl taint nodes --all node-role.kubernetes.io/master-

echo "[TASK 7] kubectx"
rm -rf /opt/kubectx > /dev/null 2>&1
rm -f /usr/local/bin/kubectx > /dev/null 2>&1
rm -f /usr/local/bin/kubens > /dev/null 2>&1
sudo git clone https://github.com/ahmetb/kubectx /opt/kubectx
sudo ln -s /opt/kubectx/kubectx /usr/local/bin/kubectx
sudo ln -s /opt/kubectx/kubens /usr/local/bin/kubens
echo "PATH=$PATH:/usr/local/bin/" >> /etc/profile
wget https://github.com/containerd/nerdctl/releases/download/v0.16.0/nerdctl-0.16.0-linux-amd64.tar.gz -O /tmp/nerdctl.tar.gz
tar -xzf /tmp/nerdctl.tar.gz
mv nerdctl /usr/local/bin
echo "alias nerdctl='nerdctl -n k8s.io'" >> /etc/profile
