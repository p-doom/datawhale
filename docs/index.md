# datawhale
Datawhale is an open-source replacement to Datadog and Weights & Biases,
combining system- (GPU/CPU/I/O/Networking) and experiment-level (loss, lr,
norms, gradients, optimizer state, activations, attention maps) observability
(metrics/logs) for AI research.

Datawhale uses an established open-source software stack (Grafana, Loki,
Prometheus, node_exporter, dgcm_exporter) and can be seen as a  configuration
template for this stack.

Datawhale is designed to accommodate workflows from individual researchers
working locally or on academic clusters (often without `sudo` rights) to
entire research orgs with clusters in the cloud.