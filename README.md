# DevLog

DevLog is a learning project for building a small notes service and deploying it on a local Kubernetes cluster. The work will happen in stages, starting with a shell script and adding the container and cluster infrastructure afterward.

## Project plan

1. **Build the backend script** — write a Bash script that listens for HTTP requests on a TCP socket, handles a small initial set of routes, and stores notes. This is the current stage.
2. **Add persistence** — connect the service to PostgreSQL for notes and metadata, then add a separate volume for file attachments.
3. **Containerize the service** — create a lean image with the required shell, networking, and database client tools.
4. **Deploy to kind** — define Kubernetes configuration, storage, and services for the backend and database.
5. **Add ingress and validate** — route local requests through an NGINX Ingress controller and exercise the endpoints with `curl`.

## Planned architecture

The target setup separates the backend, database, attachment storage, and traffic routing into distinct Kubernetes resources:

- A Bash backend uses `socat` to accept TCP connections and `psql` to access PostgreSQL.
- A PostgreSQL StatefulSet stores structured data on a persistent volume.
- A separate persistent volume holds uploaded attachments.
- ConfigMaps and Secrets provide runtime configuration and credentials.
- ClusterIP services connect the backend to PostgreSQL and expose the API inside the cluster.
- An NGINX Ingress controller routes requests for `devlog.local`, including `/api` traffic, to the backend.

These are the intended components, not implemented features yet. The first milestone is the standalone backend script; Kubernetes manifests and deployment steps will follow as the project develops.

## Development status

**Current focus:** shell-based client and backend, with initial container images.

The repository currently contains the Bash client and backend scripts and Dockerfiles for building separate client and backend images. Kubernetes manifests, database deployment configuration, and an automated deployment workflow are still planned.

## Project directory structure

```text
devlog/
├── README.md                         # Project overview, plans, and this directory guide
├── main.sh                           # Client entry point; loads cli.sh and starts the menu
├── cli.sh                            # Interactive notes client and local Age encryption helpers
├── backend.sh                        # Bash HTTP listener and backend request/database logic
└── containerfiles/
    ├── README.md                     # Build, transfer, volume, and run instructions for containers
    ├── client/
    │   └── dockerfile                # Client image definition (Alpine, Bash, curl, Age)
    └── backend/
        └── dockerfile                # Backend image definition
```

### Main files and directories

- **`main.sh`** starts the interactive client by sourcing `cli.sh` and calling its menu handler.
- **`cli.sh`** provides the notes menu, local file handling, and Age encryption/decryption functions. It sends HTTP requests to the backend using `BACKEND_URL` and stores local note files under `/mnt/backupdir`.
- **`backend.sh`** contains the `socat` TCP listener and request parsing/database integration logic. The backend image and runtime configuration are still being developed.
- **`containerfiles/client/dockerfile`** builds the interactive client image. It uses `sleep infinity` as the container command so a user can enter the container and start `main.sh` manually.
- **`containerfiles/backend/dockerfile`** is the starting point for building the backend image.
- **`containerfiles/README.md`** documents building the client image with Podman, transferring it to Docker, and creating/mounting the client volume. Podman and Docker have separate image and volume stores.
The tree above reflects the files currently in the repository. Kubernetes manifests and database deployment files will be added as those parts are implemented.
