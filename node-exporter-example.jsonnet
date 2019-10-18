local k = import 'ksonnet/ksonnet.beta.3/k.libsonnet';
local daemonset = k.apps.v1beta2.daemonSet;
local container = daemonset.mixin.spec.template.spec.containersType;
local volume = daemonset.mixin.spec.template.spec.volumesType;
local containerVolumeMount = container.volumeMountsType;

local kp =
  (import 'kube-prometheus/kube-prometheus.libsonnet') +
  // Uncomment the following imports to enable its patches
  // (import 'kube-prometheus/kube-prometheus-anti-affinity.libsonnet') +
  // (import 'kube-prometheus/kube-prometheus-managed-cluster.libsonnet') +
  // (import 'kube-prometheus/kube-prometheus-node-ports.libsonnet') +
  // (import 'kube-prometheus/kube-prometheus-static-etcd.libsonnet') +
  // (import 'kube-prometheus/kube-prometheus-thanos-sidecar.libsonnet') +
  {
    _config+:: {
      namespace: 'monitoring',
    },
    nodeExporter+: {
      daemonset+:
        local procVolumeName = 'proc';
        local procVolume = volume.fromHostPath(procVolumeName, '/proc');
        local procVolumeMount = containerVolumeMount.new(procVolumeName, '/host/proc');

        local sysVolumeName = 'sys';
        local sysVolume = volume.fromHostPath(sysVolumeName, '/sys');
        local sysVolumeMount = containerVolumeMount.new(sysVolumeName, '/host/sys');
  
        local rootVolumeName = 'root';
        local rootVolume = volume.fromHostPath(rootVolumeName, '/');
        local rootVolumeMount = containerVolumeMount.new(rootVolumeName, '/host/root').
          withMountPropagation('Bidirectional');

        container.withVolumeMounts([procVolumeMount, sysVolumeMount, rootVolumeMount]) +

        daemonset.mixin.spec.template.spec.withVolumes([procVolume, sysVolume, rootVolume]),
    },
  };

{ ['00namespace-' + name]: kp.kubePrometheus[name] for name in std.objectFields(kp.kubePrometheus) } +
{ ['0prometheus-operator-' + name]: kp.prometheusOperator[name] for name in std.objectFields(kp.prometheusOperator) } +
{ ['node-exporter-' + name]: kp.nodeExporter[name] for name in std.objectFields(kp.nodeExporter) } +
{ ['kube-state-metrics-' + name]: kp.kubeStateMetrics[name] for name in std.objectFields(kp.kubeStateMetrics) } +
{ ['alertmanager-' + name]: kp.alertmanager[name] for name in std.objectFields(kp.alertmanager) } +
{ ['prometheus-' + name]: kp.prometheus[name] for name in std.objectFields(kp.prometheus) } +
{ ['prometheus-adapter-' + name]: kp.prometheusAdapter[name] for name in std.objectFields(kp.prometheusAdapter) } +
{ ['grafana-' + name]: kp.grafana[name] for name in std.objectFields(kp.grafana) }