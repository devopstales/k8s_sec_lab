```
kubectl apply -f demo/cilium-test-psp.yaml
kubectl apply -f demo/cilium-demo-psp.yaml
```

```
kubectl create -f https://raw.githubusercontent.com/cilium/cilium/v1.9/examples/minikube/http-sw-app.yaml

kubectl exec xwing -- curl -s -XPOST deathstar.default.svc.cluster.local/v1/request-landing
Ship landed
kubectl exec tiefighter -- curl -s -XPOST deathstar.default.svc.cluster.local/v1/request-landing
Ship landed
```

Check  on hubble

```
kubectl create ns cilium-test
kubectl apply -n cilium-test -f https://raw.githubusercontent.com/cilium/cilium/v1.9/examples/kubernetes/connectivity-check/connectivity-check.yaml
```
