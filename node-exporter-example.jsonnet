local k = import 'ksonnet/ksonnet.beta.3/k.libsonnet';
local daemonset = k.apps.v1beta2.daemonSet;
local container = daemonset.mixin.spec.template.spec.containersType;
local containerPort = container.portsType;
local volume = daemonset.mixin.spec.template.spec.volumesType;
local containerVolumeMount = container.volumeMountsType;
local containerEnv = container.envType;

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

        local nodeExporter =
          container.new('node-exporter', $._config.imageRepos.nodeExporter + ':' + $._config.versions.nodeExporter) +
          container.withArgs([
            '--web.listen-address=127.0.0.1:' + $._config.nodeExporter.port,
            '--path.procfs=/host/proc',
            '--path.sysfs=/host/sys',

            // The following settings have been taken from
            // https://github.com/prometheus/node_exporter/blob/0662673/collector/filesystem_linux.go#L30-L31
            // Once node exporter is being released with those settings, this can be removed.
            '--collector.filesystem.ignored-mount-points=^/(dev|proc|sys|var/lib/docker/.+)($|/)',
            '--collector.filesystem.ignored-fs-types=^(autofs|binfmt_misc|cgroup|configfs|debugfs|devpts|devtmpfs|fusectl|hugetlbfs|mqueue|overlay|proc|procfs|pstore|rpc_pipefs|securityfs|sysfs|tracefs)$',
          ]) +
          container.withVolumeMounts([procVolumeMount, sysVolumeMount]) +
          container.mixin.resources.withRequests($._config.resources['node-exporter'].requests) +
          container.mixin.resources.withLimits($._config.resources['node-exporter'].limits);

        local ip = containerEnv.fromFieldPath('IP', 'status.podIP');
        local proxy =
          container.new('kube-rbac-proxy', $._config.imageRepos.kubeRbacProxy + ':' + $._config.versions.kubeRbacProxy) +
          container.withArgs([
            '--logtostderr',
            '--secure-listen-address=$(IP):' + $._config.nodeExporter.port,
            '--tls-cipher-suites=' + std.join(',', $._config.tlsCipherSuites),
            '--upstream=http://127.0.0.1:' + $._config.nodeExporter.port + '/',
          ]) +
          // Keep `hostPort` here, rather than in the node-exporter container
          // because Kubernetes mandates that if you define a `hostPort` then
          // `containerPort` must match. In our case, we are splitting the
          // host port and container port between the two containers.
          // We'll keep the port specification here so that the named port
          // used by the service is tied to the proxy container. We *could*
          // forgo declaring the host port, however it is important to declare
          // it so that the scheduler can decide if the pod is schedulable.
          container.withPorts(containerPort.new($._config.nodeExporter.port) + containerPort.withHostPort($._config.nodeExporter.port) + containerPort.withName('https')) +
          container.mixin.resources.withRequests({ cpu: '10m', memory: '20Mi' }) +
          container.mixin.resources.withLimits({ cpu: '20m', memory: '60Mi' }) +
          container.withEnv([ip]);

        daemonset.mixin.spec.template.spec.withContainers([nodeExporter, proxy]),
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