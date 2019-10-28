# kube-prometheus-jsonnet

Jsonnet configuration derived from [kube-prometheus](https://github.com/coreos/kube-prometheus)

## Dependencies

Install these tools before you begin using [kube-prometheus](https://github.com/coreos/kube-prometheus#installing)

- [jsonnet](https://github.com/google/jsonnet)
- [jsonnet-bundler](https://github.com/jsonnet-bundler)
- [gojsontoyaml](https://github.com/brancz/gojsontoyaml)

## Usage

Build the kubernetes object definitions

```bash
./build.sh <jsonnet-file>
```

Create the kubernetes objects

```bash
kubectl apply -f manifests/
```

Port forward services

```bash
namespace=monitoring kubectl --namespace "${namespace}" port-forward svc/grafana 3000
namespace=monitoring kubectl --namespace "${namespace}" port-forward service/alertmanager-main 9093
namespace=monitoring kubectl --namespace "${namespace}" port-forward service/prometheus-k8s 9090
```
