# k8s_sec_lab

This repository contains the manifest for my [blogposts](https://devopstales.github.io/?utm_source=github&utm_medium=link&utm_campaign=k8s_sec_lab)

```bash
helm repo add cilium https://helm.cilium.io/
helm repo update

helm upgrade --install cilium cilium/cilium   --namespace kube-system -f values.yaml

kubectl taint nodes --all node-role.kubernetes.io/master-
```

```bash
flux bootstrap github \
  --owner=$GITHUB_USER \
  --repository=k8s_sec_lab \
  --branch=main \
  --path=./k8s-manifest-gitops/flux \
  --personal
```
