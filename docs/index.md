<h2>
  <a target="_blank" href="https://github.com/p-doom/datawhale">
    <picture>
      <img alt="datawhale" src="https://raw.githubusercontent.com/p-doom/datawhale/master/docs/assets/images/datawhale-logo.png" width="350px"/>
    </picture>
  </a>
</h2>

# datawhale

[![License](https://img.shields.io/github/license/p-doom/datawhale)](https://github.com/p-doom/datawhale/blob/main/LICENSE)
[![Discord](https://img.shields.io/badge/p(doom)-Discord-%235865F2.svg?logo=discord&logoColor=white)](https://https://discord.gg/G4JNuPX2VR)

Datawhale is an open-source replacement to Datadog and Weights & Biases,
combining system- (GPU/CPU/I/O/Networking) and experiment-level (loss, lr,
norms, gradients, optimizer state, activations, attention maps) observability
(metrics/logs) for AI research.

Datawhale uses an established open-source software stack (Grafana, Loki,
Prometheus, node_exporter, dgcm_exporter) and can be seen as a configuration
template for this stack.

Datawhale is designed to accommodate workflows from individual researchers
working locally or on academic clusters (often without `sudo` rights) to
entire research orgs with clusters in the cloud.

## Installation
Datawhale supports single-server as well as multi-server configurations.
Remote clusters usually require the multi-server installation path, such
that jobs can be monitored across multiple nodes from a central location.
Datawhale distinguishes between one `server` and multiple `clients`. A
familiar analogy are the login (`server`) and compute (`client`) nodes on
an HPC cluster.

Installing datawhale is as simple as cloning the repository and running `setup.sh`:
```bash
git clone https://github.com/p-doom/datawhale.git
# server installation
bash scripts/setup.sh ROLE=server MODE=standalone
# client installation
bash scripts/setup.sh ROLE=client MODE=standalone
```

We currently only support the `standalone` installation path. The `server`
installation downloads prebuilt binaries of Grafana, Loki and Prometheus, while
the `client` installation downloads node_exporter, and, depending on the
availability, dcgm_exporter or nvml_exporter. Notably, this does not require 
package manager access, `sudo` rights, or cluster-side Docker support, and can
thus be run on any (academic|on-prem|cloud) cluster. Docker-based installation
support is on the roadmap. We currently only support `amd64-linux`, but the 
repository should be easily extendable to other architectures and operating
systems. 

You can run datawhale using `deploy.sh`:
```bash
bash scripts/deploy.sh ROLE=<server|client> MODE=standalone
```

