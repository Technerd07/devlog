# DevLog Kubernetes Lab Notes

## Lab context

This lab deploys the DevLog database and shell client into a local kind cluster. I created the Kubernetes resources by hand, applied them with `kubectl`, inspected the resulting objects, and debugged issues by comparing the manifests with the live cluster state. The work focused on the Kubernetes control plane relationships between Deployments, Pods, Services, probes, images, and persistent storage.

## Workload and resource design

### PostgreSQL workload

- Created a PostgreSQL Deployment named `devlog-db` with one replica. Its selector and Pod template use the label `app: devlog-db`.
- Configured the official PostgreSQL image with the initial database name and role through container environment variables.
- Added an `exec` readiness probe using `pg_isready` against localhost on TCP port `5432`. The probe reports whether the database server is accepting connections; it does not replace an application-level authentication test.
- Mounted the `postgres-pvc` claim into `/var/lib/postgresql/data`, the PostgreSQL data directory, through a Pod volume named `postgres-storage`.

### Client workload

- Created a client Deployment named `devlog-client`, with one replica and Pod label `app: devlog-client`.
- Loaded the locally built client image into the kind node and configured the workload to use the preloaded image.
- Set `DB_HOST` to the database Service DNS name, `devlog-db-svc`. The backend process in the client container uses that host to reach PostgreSQL on port `5432`.
- Fixed the backend's `DB_HOST` value from the incorrect Service hostname to `devlog-db-svc`; after that correction, the client-to-backend-to-PostgreSQL note flow worked and notes were stored successfully.
- Kept the client container alive for interactive use, then used `kubectl exec` to enter it and run commands. The sleep process is only a container keepalive; it does not itself launch the DevLog backend or interactive client scripts.
- Added CPU and memory requests and limits. The current manifest requests and limits one CPU and `500Mi` of memory. Requests influence scheduling; limits cap resource use.
- Mounted the `devlog-client-pvc` claim at `/mnt/backupdir` for client-side files.

## Service discovery and traffic flow

- Created a `ClusterIP` Service named `devlog-db-svc` on port `5432`, targeting port `5432` on Pods selected by `app: devlog-db`.
- The Service selector matches the Pod template label, not the Deployment object name. Once the Deployment existed and its database Pod was Ready, the Service had a Pod IP and port in its endpoint data.
- The intended in-cluster path is: client/backend process → DNS name `devlog-db-svc` → Service port `5432` → ready PostgreSQL Pod target port `5432`.
- The Service provides a stable name even if the Deployment replaces the Pod and its IP changes. The Service is internal to the cluster; no Ingress is needed for PostgreSQL traffic.

## Persistent storage observations

- Created separate PVCs for PostgreSQL and the client. Each requested `2Gi` with `ReadWriteOnce` access.
- Observed the PostgreSQL claim transition from `Pending` to `Bound` as the kind local-path provisioner created a backing PV.
- Confirmed the database PV reported `2Gi` capacity and referenced `default/postgres-pvc` as its claim.
- A PVC is only attached to a workload when the Pod spec declares a volume referencing its `claimName`, and a container mounts that volume by the matching volume name.
- The `volumes` list belongs under the Pod spec, next to `containers`. Each container's `volumeMounts` list belongs inside its container item. The mount name must equal the Pod volume name; `claimName` must equal the PVC metadata name.
- Mounted PostgreSQL data at `/var/lib/postgresql/data`. Checking the parent directory can be misleading; inspect the actual mount path.
- `df` inside the Pod showed the large underlying kind node filesystem rather than a 2Gi filesystem. The PVC/PV reported the requested 2Gi capacity, while kind's local-path storage does not necessarily impose a hard filesystem quota at that size.

## Image distribution and runtime debugging

- Built local images for the DevLog client and database, loaded them into the kind cluster, and inspected the node's container runtime using `docker exec` with `crictl images` and `crictl ps`.
- Learned that a locally available image on the host is separate from the image store used by kind nodes. The image must be loaded into kind, and the manifest's repository/name and tag must match the loaded reference.
- Investigated `ErrImagePull` and `ImagePullBackOff`. The client image was present in the node; subsequent failures came from invalid container startup commands rather than image distribution.
- Used `imagePullPolicy: Never` during local testing so Kubernetes would only use the image already loaded into kind. This is useful for local images but will fail if the image is absent on a node.
- Container `command` is an argument array. `command: ["sh -c sleep infinity"]` asks Kubernetes to execute a binary with that literal name. For a shell command, pass each shell argument separately and provide the complete command string as one argument, e.g. `["sh", "-c", "sleep 365d"]`.
- The BusyBox `sleep` in the client image did not accept `infinity`; it printed usage and exited. A supported finite duration such as `sleep 365d` kept the interactive toolbox container alive.
- Read Pod events, container logs, restart counts, and termination state to distinguish image-pull errors from startup-process errors. A successful pull and container start event do not guarantee the process remains running.
- `kubectl rollout status` reports Deployment rollout progress, but I also checked Pod readiness and status. A restarting Pod can still have a rollout report that is not a substitute for inspecting the Pod itself.

## Manifest structure and object relationships

- A Deployment's `spec.selector.matchLabels` must match its Pod template labels under `spec.template.metadata.labels`; Deployment selectors are immutable after creation in common Kubernetes API behavior, so choose stable labels.
- A Service's `spec.selector` matches Pod labels. The Service metadata labels are separate and do not determine which Pods it routes to.
- Container settings such as `image`, `env`, `command`, `resources`, and `volumeMounts` are siblings within one container object. Pod-level `volumes` is a sibling of `containers` under `spec.template.spec`.
- YAML indentation determines the object tree. A misplaced dash under `containers` creates another container entry, and a field indented outside the container or Pod spec is rejected or interpreted at the wrong schema level.
- Kubernetes manages object status fields. Manifests should describe desired state; generated `status` content should not be authored into them.

## PostgreSQL identity and probe distinction

- `POSTGRES_USER` and `POSTGRES_DB` initialize the PostgreSQL role and database when the official image initializes a new data directory. These settings do not change the container's Linux user or every client's PostgreSQL connection identity.
- A `psql` invocation with no `-U` defaults to the operating-system username. When that user is `root`, PostgreSQL reports that role `root` does not exist. Passing `-U devlog` explicitly selects the configured database role.
- The readiness probe runs in the database container and can specify `-U devlog`; it does not cause unrelated client processes to connect as `root`.
- Readiness controls whether a Pod is considered ready for Service traffic. It checks the server's connection readiness, while a real client request or authenticated SQL query verifies more of the application path.

## Current resource inventory

| Resource | Name | Purpose |
| --- | --- | --- |
| Deployment | `devlog-db` | Runs one PostgreSQL Pod |
| Service | `devlog-db-svc` | Provides stable in-cluster PostgreSQL discovery on port 5432 |
| PVC | `postgres-pvc` | Requests 2Gi for PostgreSQL data |
| Deployment | `devlog-client` | Runs the DevLog client image for interactive use |
| PVC | `devlog-client-pvc` | Requests 2Gi for client-side files |
