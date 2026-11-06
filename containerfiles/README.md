# Devlog Containers

## Use the client image with Podman or Docker

The client image can be built and run with either Podman or Docker. This workflow builds the image with Podman, saves it as an archive, then loads that same image into Docker.

### 1. Build with Podman

Run from the repository root:

```sh
podman build -f containerfiles/client/dockerfile -t devlog-client-podman .
```

### 2. Create the client volume in Podman

Create one named volume for the client's local note files:

```sh
podman volume create devlog-client-vol
```

Podman and Docker keep separate volume stores. Create a volume with the same name in Docker too; the name is the same, but the volume data is not shared automatically between engines.

### 3. Save the image and load it into Docker

Save the Podman image to a tar archive:

```sh
podman save -o devlog-client.tar devlog-client-podman
```

Load that archive into Docker:

```sh
docker load -i ./devlog-client.tar
```

Docker will list the loaded image under the `devlog-client-podman` tag. Check with:

```sh
docker images devlog-client-podman
```

### 4. Create the Docker volume

```sh
docker volume create devlog-client-vol
```

### 5. Start the client

The image runs `sleep infinity` so you can enter the container and launch the interactive menu manually. The volume is mounted at `/mnt/backupdir`:

```sh
podman run -d --name devlog-client \
  -v devlog-client-vol:/mnt/backupdir \
  -e BACKEND_URL=http://backend:9090 \
  devlog-client-podman
```

For Docker, use the same volume mount and image tag:

```sh
docker run -d --name devlog-client \
  -v devlog-client-vol:/mnt/backupdir \
  -e BACKEND_URL=http://backend:9090 \
  devlog-client-podman
```

Set `BACKEND_URL` to a hostname and port the client container can reach. For example, `backend` works when the backend container is reachable by that name on a shared container network. `localhost` refers to the client container itself, not another container.

### 6. Open a shell and run the menu

With Podman:

```sh
podman exec -it devlog-client bash
cd /client-app
bash ./main.sh
```

With Docker:

```sh
docker exec -it devlog-client bash
cd /client-app
bash ./main.sh
```

`main.sh` sources `cli.sh` and starts the menu. `cli.sh` only defines the functions. The client uses `curl`, `age`, and `bash`; note editing also requires an editor such as `vim` to be installed or configured.

## Devlog introduction

Devlog is a command-line notes project. The client provides menu options to create, update, and list notes. It sends requests to the backend and keeps an encrypted local copy of notes using Age. The backend must be running and reachable for server requests to work.

Age creates an identity at `~/.config/age/devlog-identity.txt` on first encryption (typically `/root/.config/age/devlog-identity.txt` in the container). Preserve the matching identity securely if you need to decrypt existing notes. The client volume stores the encrypted note files; it does not automatically preserve the Age identity.

## Notes about volumes

The `devlog-client-vol` volume persists files when the client container is removed and recreated within the same engine. Podman and Docker have separate volume stores, so a same-named volume in each engine starts with separate data. To move note data between engines, back up and restore the volume contents separately.
