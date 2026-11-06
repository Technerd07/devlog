# Devlog Client Container

Devlog is a small command-line notes project. The client presents a menu for creating, updating, and listing notes. It sends requests to the backend and stores an encrypted local copy using Age.

## Build the image

Run these commands from the repository root:

```sh
podman build -f containerfiles/client/dockerfile -t devlog-client .
```

## Start the container

The image stays running with `sleep infinity` so you can enter it and run the client interactively. Mount a named volume at `/home/backupdir` to retain local note files:

```sh
podman volume create devlog-data
podman run -d --name devlog-client \
  -v devlog-data:/home/backupdir \
  -e BACKEND_URL=http://backend:9090 \
  devlog-client
```

Use the backend service's reachable hostname in `BACKEND_URL`. For containers in the same Podman pod, `localhost` can work when the backend listens on port 9090; on a shared network, use its container or service name.

## Run the menu

Open an interactive shell in the running container, then start `main.sh`:

```sh
podman exec -it devlog-client bash
cd /client-app
bash ./main.sh
```

`main.sh` sources `cli.sh` and calls its menu handler. `cli.sh` alone defines functions and does not start the menu.

Choose an option from the menu. Creating and editing notes uses the configured editor (defaults to `vim`); install or provide an editor if needed. The client container currently installs `curl`, `age`, and `bash`.

## Age identity

Age creates an identity at `~/.config/age/devlog-identity.txt` on first encryption. In the container, this is typically `/root/.config/age/devlog-identity.txt`. Keep this file private and persist it if you need to decrypt notes after recreating the container. For example, mount a protected host directory at `/root/.config/age`:

```sh
-v "$HOME/.config/age:/root/.config/age"
```

The note volume and identity are separate: the encrypted files are not decryptable without the matching identity.

## Current development notes

- The local note directory is `/home/backupdir`.
- The default backend URL is `http://localhost:9090`; set `BACKEND_URL` when starting the container to match your Podman network.
- The backend must be running and reachable for requests to succeed.
- This image is configured for interactive development, not as a long-running production client service.
