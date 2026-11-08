# DevLog container setup

This guide describes the current Podman development setup. The running client container is named `linux-sandbox`, the PostgreSQL container is named `devlog-db`, and both use the `devlog-network` network. The client container also has the PostgreSQL command-line client (`psql`) installed so the backend script can connect to the database.

## Current verified setup

The containers were connected to the same Podman network, and connectivity was checked from `linux-sandbox`:

```sh
podman network inspect devlog-network
podman exec linux-sandbox getent hosts devlog-db
```

The hostname lookup returned an address for `devlog-db`. A direct `psql` connection from the client container also succeeded and listed the database tables. This verifies container DNS and PostgreSQL access from `linux-sandbox` to `devlog-db`.

## Attach existing containers to the network

The network and containers already exist, so connect them rather than creating duplicate containers:

```sh
podman network connect devlog-network linux-sandbox
podman network connect devlog-network devlog-db
```

If a container is already attached, Podman may report that it is connected; inspect the network to confirm both names are listed:

```sh
podman network inspect devlog-network
```

The backend uses `DB_HOST=devlog-db`, `DB_NAME=devlog`, and `DB_USER=devlog` by default. The PostgreSQL container must have been initialized with matching database/user settings and a password known to the backend. PostgreSQL's data directory is persisted in the database volume.

## Check PostgreSQL from the client container

Confirm name resolution:

```sh
podman exec linux-sandbox getent hosts devlog-db
```

Connect with `psql` and list tables. It will prompt for the database password:

```sh
podman exec -it linux-sandbox psql \
  -h devlog-db -p 5432 -U devlog -d devlog \
  -c '\dt'
```

The backend also needs `psql` installed in the container where `backend.sh` runs. A successful manual `psql` command confirms the client is present and can reach PostgreSQL; if the backend still fails, inspect its runtime `DB_HOST`, `DB_NAME`, `DB_USER`, and password settings and read the `psql` error output.

## Run the application scripts

Run the backend and client from the directory containing their scripts and `logs.sh`, because the scripts source sibling files using relative paths. Start the backend in one terminal:

```sh
podman exec -it linux-sandbox sh
cd /work
bash backend.sh
```

In another terminal, open the client container and start the interactive client:

```sh
podman exec -it linux-sandbox sh
cd /work
bash main.sh
```

If the scripts are located in another directory in the container, change to that directory instead. The client defaults to `BACKEND_URL=http://localhost:9090`, which works when the backend runs in the same container. If client and backend are split into separate containers, attach both to `devlog-network` and set `BACKEND_URL` to the backend container name and port, for example `http://backend:9090`.

## Volumes and persistence

The setup uses named Podman volumes so local encrypted notes and PostgreSQL data can persist when containers are recreated. Podman volume names are specific to the local Podman installation; list the actual names with:

```sh
podman volume ls
podman inspect linux-sandbox
podman inspect devlog-db
```

Keep the existing volume mounted to PostgreSQL's data directory (`/var/lib/postgresql/data`) when recreating `devlog-db`. Keep the client volume mounted at the path used for local notes (the script defaults to `/mnt/backupdir`). Do not remove these volumes when replacing containers if you need their data.

Age stores its identity separately at `~/.config/age/devlog-identity.txt` (commonly under `/root` in a container). Preserve that identity too if you need to decrypt existing local notes; the notes volume alone may not contain it.

## Current image build status

The live containers have been configured and tested manually. The Dockerfiles still need to be aligned with the current repository layout under `shellscripts/`: the client Dockerfile references scripts at the repository root, and it does not currently install `postgresql-client`. Rebuildable image instructions will be added after those build contexts and runtime packages are corrected.
