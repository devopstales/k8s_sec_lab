#!/bin/bash

# reset kubeadm
#echo "[TASK 0] Reset kubeadm"
#kubeadm reset -f > /dev/null 2>&1
#rm -f /vagrant/admin.conf > /dev/null 2>&1
#rm -rf /home/vagrant/.kube > /dev/null 2>&1
#rm -rf /root/.kube > /dev/null 2>&1


# Join worker nodes to the Kubernetes cluster
echo "[TASK 1] Join node to Kubernetes Cluster"
bash /vagrant/joincluster.sh >/dev/null 2>&1

echo "[TASK 2] Correct node ip in kubelet"
echo KUBELET_EXTRA_ARGS=\"--node-ip=`ip addr show enp0s8 | grep inet | grep -E -o "([0-9]{1,3}[\.]){3}[0-9]{1,3}/" | tr -d '/'`\" > /etc/sysconfig/kubelet
systemctl restart kubelet
