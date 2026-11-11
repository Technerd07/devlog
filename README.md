# DevLog

DevLog is a learning project for a small notes application built with Bash, PostgreSQL, and Age. The current prototype has an interactive shell client, a Bash HTTP backend, and a PostgreSQL schema. The next phase is to make the container setup reproducible and deploy it to Kubernetes.

## Demo

![DevLog demo (1:35–2:16)](docs/demo.gif)

## Repository structure

```text
devlog/
├── README.md
├── docs/
│   |── demo.gif                    # Short animated preview
├── shellscripts/
│   ├── main.sh                     # Interactive client entry point
│   ├── cli.sh                      # Menu, HTTP client, local Age encryption
│   ├── backend.sh                  # HTTP listener and PostgreSQL writes
│   └── logs.sh                     # Logging helper
└── containerfiles/
    ├── README.md                   # Container workflow notes
    ├── client/
    │   └── dockerfile              # Client image definition
    └── backend/
        ├── dockerfile              # PostgreSQL image definition
        ├── schema.sql              # Notes table schema
        └── ref.txt                 # Backend container notes
```

The shell scripts source sibling files by relative path, so run them from `shellscripts/`. Kubernetes manifests and deployment automation do not exist in the repository yet.

## Current prototype

- The client provides an interactive menu and stores local note files encrypted with Age.
- The client sends note requests to the backend over HTTP.
- The backend listens on port `9090` and uses `psql` to write notes to PostgreSQL.
- `containerfiles/backend/schema.sql` defines the PostgreSQL notes table.

The client retrieval and edit flows and the container packaging are still being developed. Review [containerfiles/README.md](containerfiles/README.md) and the Dockerfiles before building; the current paths and build instructions may need alignment with the `shellscripts/` layout.

## Kubernetes roadmap

### 1. Make container deployment reproducible

Align image build contexts with the repository layout, install each service's runtime dependencies, externalize credentials, and document container networking and persistent volumes. Verify the client, backend, and database communicate through named services before moving to Kubernetes.

### 2. Implement Kubernetes resources

Add manifests for:

- A backend Deployment and ClusterIP Service.
- A PostgreSQL StatefulSet, Service, and PersistentVolumeClaim.
- ConfigMaps for non-sensitive settings and Secrets for database credentials.
- Optional ingress resources after the in-cluster service path is working.

### 3. Deploy and validate on a manually managed cluster

Document how to configure `kubectl` for a manually managed cluster, load or publish the required images, apply the manifests, and verify pod readiness, service discovery, database persistence, and note creation. Keep cluster-specific storage classes, image registries, and ingress settings configurable rather than assuming they match the local setup.

### 4. Automate local-cluster testing

Create a repeatable local workflow using kind as the initial target (with Minikube as an optional target). It should create or select the cluster, build and load images, apply the same Kubernetes manifests, wait for readiness, run smoke tests, and clean up test resources. This provides a quick regression check without replacing validation on the manually managed cluster.

### 5. Add ingress and end-to-end checks

Install or document an ingress controller for the chosen cluster, route a local hostname to the backend, and test the user-facing request path with `curl` and the CLI.

## Requirements

For shell and container development, use Bash, Age, `curl`, `socat`, the PostgreSQL client (`psql`), and Podman or Docker. Kubernetes work will additionally use `kubectl` and access to either a manually managed Kubernetes cluster or a local kind cluster; Minikube may be used as an alternative local cluster. Cluster creation, image loading, storage, and ingress steps differ by target and will be documented as the deployment workflow is implemented.
