# datawhale

[![License](https://img.shields.io/github/license/p-doom/datawhale)](https://github.com/p-doom/datawhale/blob/main/LICENSE)
[![Discord](https://img.shields.io/badge/p(doom)-Discord-%235865F2.svg?logo=discord&logoColor=white)](https://https://discord.gg/G4JNuPX2VR)

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

## Installation

Installing datawhale is as simple as cloning the repository and running `setup.sh`:
```bash
git clone https://github.com/p-doom/datawhale.git
bash scripts/setup.sh MODE=standalone
```

We currently only support the `standalone` installation path, which downloads prebuilt binaries of Grafana, Loki, Prometheus, and node_exporter. Notably, this does not require package manager access, `sudo` rights, or cluster-side Docker support, and can thus be run on any (academic|on-prem|cloud) cluster. Docker-based installation support is on the roadmap.

You can run datawhale using `deploy.sh`:
```bash
bash scripts/deploy.sh
```

