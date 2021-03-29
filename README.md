
# Technologies
The technologies down here will probably change in the future. Nevertheless, the following table should provide you a small overview over currently used technologies.

| What                   | Technology                                      | Status |
| ---------------------- | ----------------------------------------------- | ------ |
| OS (Intel NUC)         | AlmaLinux 8.3                                   |  DONE  |
| Distributon            | Rancher (RKE2)                                  |  DONE  |
| CRI                    | containerd (included in RKE2)                   |  DONE  |
| CNI                    | Cilium                                          |  DONE  |
| CSI                    | Project Longhorn                                |        |
| Certificate Handling   | Cert-Manager with Private CA                    |  DONE  |
| Control Plane          | Rancher 2.5                                     |        |
| Control Plane Backup   | Rancher Backup                                  |        |
| Persistent Data Backup | Kanister                                        |        |
| App Deployment         | Helm & Fleet                                    |        |

# Table of Content
- [Prerequisites](#prerequisites)
  - [Host OS](#host-os)
    - [Disable Swap](#disable-swap)
- [K8s Cluster Setup](#k8s-cluster-setup)
  - [RKE2 Setup](#rke2-setup)
    - [Project Longhorn Prerequisites](#project-longhorn-prerequisites)
    - [RKE2 rpm Install](#rke2-rpm-install)
    - [Kubectl, Helm & RKE2](#kubectl-helm--rke2)
    - [Firewall](#firewall)
    - [Basic Configuration](#basic-configuration)
    - [Prevent RKE2 Package Updates](#prevent-rke2-package-updates)
  - [Starting RKE2](#starting-rke2)
  - [Configure Kubectl (on RKE2 Host)](#configure-kubectl-on-rke2-host)
- [Basic Infrastructure Components](#basic-infrastructure-components)
  - [Networking using Cilium (CNI)](#networking-using-cilium-cni)
    - [Cilium Prerequisites](#cilium-prerequisites)
    - [Cilium Installation](#cilium-installation)

# Prerequisites

## Host OS
Download and install almalinux 8.3.

### Disable Swap
```bash
free -h
sudo swapoff -a
sed -i.bak -r 's/(.+ swap .+)/#\1/' /etc/fstab
free -h
```

# K8s Cluster Setup
## RKE2 Setup

### Project Longhorn Prerequisites
```bash
yum install -y epel-release
yum install -y iscsi-initiator-utils
modprobe iscsi_tcp
echo "iscsi_tcp" >/etc/modules-load.d/iscsi-tcp.conf
systemctl enable iscsid
systemctl start iscsid 
```

### RKE2 rpm Install
```bash
cat << EOF > /etc/yum.repos.d/rancher-rke2-1-18-latest.repo
[rancher-rke2-common-latest]
name=Rancher RKE2 Common Latest
baseurl=https://rpm.rancher.io/rke2/latest/common/centos/8/noarch
enabled=1
gpgcheck=1
gpgkey=https://rpm.rancher.io/public.key

[rancher-rke2-1-18-latest]
name=Rancher RKE2 1.18 Latest
baseurl=https://rpm.rancher.io/rke2/latest/1.18/centos/8/x86_64
enabled=1
gpgcheck=1
gpgkey=https://rpm.rancher.io/public.key
EOF
```

```bash
yum install -y rke2-server nano net-tools htop tmux git
```

### Kubectl, Helm & RKE2
Install `kubectl`, `helm` and RKE2 to the host system:
```bash
mkdir -p /var/lib/rancher/rke2/agent/images/
cp /vagrant/rke2-images.linux-amd64.tar.gz /var/lib/rancher/rke2/agent/images/

sudo git clone https://github.com/ahmetb/kubectx /opt/kubectx
sudo ln -s /opt/kubectx/kubectx /usr/local/bin/kubectx
sudo ln -s /opt/kubectx/kubens /usr/local/bin/kubens
echo 'PATH=$PATH:/usr/local/bin' >> /etc/profile
echo 'PATH=$PATH:/var/lib/rancher/rke2/bin' >> /etc/profile
source /etc/profile

sudo dnf copr enable cerenit/helm
sudo dnf install -y helm
```

### Firewall
Ensure to open the required ports:
```bash
setenforce 1
getenforce
sed -i 's/=\(disabled\|permissive\)/=enforcing/g' /etc/sysconfig/selinux
systemctl start firewalld
systemctl enable firewalld

### RKE2 specific ports
```bash
sudo firewall-cmd --add-port=9345/tcp --permanent
sudo firewall-cmd --add-port=6443/tcp --permanent
sudo firewall-cmd --add-port=10250Air-Gap/tcp --permanent
sudo firewall-cmd --add-port=2379/tcp --permanent
sudo firewall-cmd --add-port=2380/tcp --permanent
sudo firewall-cmd --add-port=30000-32767/tcp --permanent
# Used for the Rancher Monitoring
sudo firewall-cmd --add-port=9796/tcp --permanent
sudo firewall-cmd --add-port=19090/tcp --permanent
sudo firewall-cmd --add-port=6942/tcp --permanent
sudo firewall-cmd --add-port=9091/tcp --permanent
### CNI specific ports
# 4244/TCP is required when the Hubble Relay is enabled and therefore needs to connect to all agents to collect the flows
sudo firewall-cmd --add-port=4244/tcp --permanent
# Cilium healthcheck related permits:
sudo firewall-cmd --add-port=4240/tcp --permanent
sudo firewall-cmd --remove-icmp-block=echo-request --permanent
sudo firewall-cmd --remove-icmp-block=echo-reply --permanent
# Since we are using Cilium with GENEVE as overlay, we need the following port too:
sudo firewall-cmd --add-port=6081/udp --permanent
### Ingress Controller specific ports
sudo firewall-cmd --add-port=80/tcp --permanent
sudo firewall-cmd --add-port=443/tcp --permanent
### To get DNS resolution working, simply enable Masquerading.
sudo firewall-cmd --zone=public  --add-masquerade --permanent

### Finally apply all the firewall changes
sudo firewall-cmd --reload
```

Verification:
```bash
sudo firewall-cmd --list-all
public (active)
  target: default
  icmp-block-inversion: no
  interfaces: eno1
  sources: 
  services: cockpit dhcpv6-client ssh wireguard
  ports: 9345/tcp 6443/tcp 10250/tcp 2379/tcp 2380/tcp 30000-32767/tcp 4240/tcp 6081/udp 80/tcp 443/tcp 4244/tcp 9796/tcp 19090/tcp 6942/tcp 9091/tcp
  protocols: 
  masquerade: yes
  forward-ports: 
  source-ports: 
  icmp-blocks: 
  rich rules: 
```

Source:
- https://docs.rke2.io/install/requirements/#networking

### Basic Configuration
```bash
mkdir -p /etc/rancher/rke2
cat << EOF >  /etc/rancher/rke2/config.yaml
write-kubeconfig-mode: "0644"
profile: "cis-1.5"
# add ips/hostname of hosts and loadbalancer
tls-san:
  - "k8s.mydomain.intra"
  - "172.17.9.10"
# Make a etcd snapshot every 6 hours
etcd-snapshot-schedule-cron: " */6 * * *"
# Keep 56 etcd snapshorts (equals to 2 weeks with 6 a day)
etcd-snapshot-retention: 56
disable:
  - rke2-canal
  - rke2-kube-proxy
EOF
```

**Note:** I disabled `rke2-canal` and `rke2-kube-proxy` since I plan to install Cilium as CNI in ["kube-proxy less mode"](https://docs.cilium.io/en/v1.9/gettingstarted/kubeproxy-free/) (`kubeProxyReplacement: "strict"`). Do not disable `rke2-kube-proxy` if you use another CNI - it will not work afterwards!

```bash
sudo cp -f /usr/share/rke2/rke2-cis-sysctl.conf /etc/sysctl.d/60-rke2-cis.conf
sysctl -p /etc/sysctl.d/60-rke2-cis.conf

useradd -r -c "etcd user" -s /sbin/nologin -M etcd

mkdir -p /var/lib/rancher/rke2/server/manifests/
cat << EOF > /var/lib/rancher/rke2/server/manifests/rke2-ingress-nginx-config.yaml
apiVersion: helm.cattle.io/v1
kind: HelmChartConfig
metadata:
  name: rke2-ingress-nginx
  namespace: kube-system
spec:
  valuesContent: |-
    controller:
      metrics:
        service:
          annotations:
            prometheus.io/scrape: "true"
            prometheus.io/port: "10254"
EOF
```


### Prevent RKE2 Package Updates
In order to provide more stability, I chose to DNF/YUM "mark/hold" the RKE2 related packages so a `dnf update`/`yum update` does not mess around with them.

Add the following line to `/etc/dnf/dnf.conf` and/or `/etc/yum.conf`:
```bash
exclude=rke2-*
```

Sources:
- https://www.systutorials.com/making-dnf-yum-not-update-certain-packages/
- https://www.commandlinefu.com/commands/view/1451/search-through-all-installed-packages-names-on-rpm-systems

## Starting RKE2
Enable the `rke2-server` service and start it:
```bash
sudo systemctl enable rke2-server --now
```

Verification:
```bash
sudo systemctl status rke2-server
sudo journalctl -u rke2-server -f
```

## Configure Kubectl (on RKE2 Host)
```bash
mkdir ~/.kube
ln -s /etc/rancher/rke2/rke2.yaml ~/.kube/config
chmod 600 /root/.kube/config
ln -s /var/lib/rancher/rke2/agent/etc/crictl.yaml /etc/crictl.yaml

kubectl get node
crictl ps
crictl images
```

Verification:
```bash
kubectl get nodes
NAME                    STATUS   ROLES         AGE     VERSION
k8s.mydomain.intra   NotReady   etcd,master   2m4s   v1.18.16+rke2r1
```

# Basic Infrastructure Components

## Networking using Cilium (CNI)

### Cilium Prerequisites

Ensure the eBFP filesystem is mounted (which should already be the case on RHEL 8.3):
```bash
mount | grep /sys/fs/bpf
# if present should output, e.g. "none on /sys/fs/bpf type bpf"...
```

If that's not the case, mount it using the commands down here:
```bash
sudo mount bpffs -t bpf /sys/fs/bpf
sudo bash -c 'cat <<EOF >> /etc/fstab
none /sys/fs/bpf bpf rw,relatime 0 0
EOF'
```

Prepare & add the Helm chart repo:
```bash
cd ~/rke2
mkdir cilium
helm repo add cilium https://helm.cilium.io/
helm repo update
```

Sources:
- https://docs.cilium.io/en/stable/operations/system_requirements/#mounted-ebpf-filesystem

### Cilium Installation

```bash
kubectl create -n kube-system secret generic cilium-ipsec-keys \
    --from-literal=keys="3 rfc4106(gcm(aes)) $(echo $(dd if=/dev/urandom count=20 bs=1 2> /dev/null| xxd -p -c 64)) 128"

kubectl -n kube-system get secrets cilium-ipsec-keys

helm upgrade --install cilium cilium/cilium   --namespace kube-system -f values.yaml
```

**Note:** Check the official [cilium/values.yaml](https://github.com/cilium/cilium/blob/master/install/kubernetes/cilium/values.yaml) in order to see all available values.

Sources:
- https://docs.cilium.io/en/stable/gettingstarted/k8s-install-default/
- https://docs.cilium.io/en/stable/gettingstarted/k8s-install-etcd-operator/
- https://docs.cilium.io/en/v1.9/gettingstarted/kubeproxy-free/

---
* https://raw.githubusercontent.com/PhilipSchmid/k8s-home-lab/master/README.md
