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

**Current focus:** backend shell script.

The repository is at the initial planning stage. No backend, container image, Kubernetes manifests, or deployment workflow has been added yet.
