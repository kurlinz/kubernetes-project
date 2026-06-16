Installs core components of the Kube-prometheus-stack, a collection of Kubernetes manifests, Grafana dashboards, and prometheus rules combined with documentation and scripts to provide easy to operate end-to-end Kubernetes cluster monitoring with prometheus using the prometheus-operator.

Prerequisites
Kubernetes 1.19+
Helm 3+

Usage
The chart is distributed as an  as well as via a traditional .

OCI Artifact: oci://ghcr.io/prometheus-community/charts/kube-prometheus-stack
Helm Repository: https://prometheus-community.github.io/helm-charts with chart kube-prometheus-stack
The installation instructions use the OCI registry. Refer to the [helm repo]() command documentation for information on installing charts via the traditional repository.

Install Helm Chart
helm install [RELEASE_NAME] oci://ghcr.io/prometheus-community/charts/kube-prometheus-stack