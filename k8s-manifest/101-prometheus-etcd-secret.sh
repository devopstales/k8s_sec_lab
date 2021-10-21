#!/bin/bash

# kubeadm
kubectl -n monitoring-system create secret generic etcd-client-cert \
--from-file=/etc/kubernetes/pki/etcd/ca.crt \
--from-file=/etc/kubernetes/pki/etcd/healthcheck-client.crt \
--from-file=/etc/kubernetes/pki/etcd/healthcheck-client.key

# rancher
#kubectl -n monitoring-system create secret generic etcd-client-cert \
#--from-file=/var/lib/rancher/rke2/server/tls/etcd/server-ca.crt \
#--from-file=/var/lib/rancher/rke2/server/tls/etcd/server-client.crt \
#--from-file=/var/lib/rancher/rke2/server/tls/etcd/server-client.key
