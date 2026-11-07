*This project has been created as part of the 42 curriculum by mnahli.*

# Inception

## Description

Inception is a system-administration project: a small web infrastructure built from scratch with Docker, where every service runs in its own container built from its own Dockerfile.

The stack serves a WordPress site over HTTPS at `https://mnahli.42.fr`:

| Service | Container | Base image | Role |
|---|---|---|---|
| NGINX | `nginx` | `debian:bookworm` | The only entry point. Listens on port 443 with TLS 1.2/1.3 and a self-signed certificate. Serves static files and forwards PHP requests to php-fpm. |
| WordPress + php-fpm | `wordpress` | `debian:bookworm` | Runs the WordPress PHP code. Listens on port 9000 (FastCGI), inside the Docker network only. Installed at first start with WP-CLI. |
| MariaDB | `mariadb` | `debian:bookworm` | The database. Listens on port 3306, inside the Docker network only. The database, the user and the root password are created at first start. |

Two named volumes keep the data on the host, in `/home/mnahli/data/mariadb` (database files) and `/home/mnahli/data/wordpress` (WordPress files, shared by nginx and php-fpm). A private bridge network `inception` connects the three containers; only nginx publishes a port.

### Main design choices

- **One process per container, PID 1 is the service itself.** Each container ends with `exec` of the real server (`mysqld`, `php-fpm8.2 -F`, `nginx -g "daemon off;"`), so `docker stop` reaches the service directly and no `tail -f` or infinite loop is needed.
- **Setup scripts that run once.** `init.sh` (MariaDB) and `setup.sh` (WordPress) check whether the volume already holds data; on the first start they create the database/users or download and install WordPress, on later starts they go straight to the server.
- **No credentials in the images.** Every password and name comes from `srcs/.env` at run time through `env_file`; the file is ignored by git.
- **Minimal packages.** Each Dockerfile installs only what a test required (for example `php8.2-fpm php8.2-mysql curl` for WordPress).
- **Penultimate stable Debian** (`bookworm`), as the subject requires, with no `latest` tag anywhere.

### Virtual machines vs Docker

A virtual machine runs a complete second operating system with its own kernel on emulated hardware; it is isolated but heavy (gigabytes, minutes to boot). A Docker container is a group of ordinary processes of the host kernel, isolated with namespaces (PID, network, mount, …) and limited with cgroups, started from an image made of read-only layers. It boots in a second and shares the kernel. Inception uses both: the containers run inside a Debian VM at evaluation, which gives a clean, reproducible host.

### Secrets vs environment variables

Environment variables are the simplest way to pass configuration into a container (`env_file`, `-e`): they are easy to use but visible to every process in the container and in `docker inspect`. Docker secrets mount each value as a file in `/run/secrets/`, readable only by the service that declares it, and are the better choice for production. This mandatory part uses environment variables from a git-ignored `.env` file, which the subject allows; the file is never committed.

### Docker network vs host network

With `network_mode: host` a container shares the host's network stack: every port it opens is a host port and containers cannot be isolated from each other. A user-defined bridge network (used here, `inception`) gives each container its own interface and IP, a built-in DNS that resolves service names (`mariadb`, `wordpress`), and lets only explicitly published ports (443) reach the outside. The subject forbids the host network.

### Docker volumes vs bind mounts

A bind mount maps an arbitrary host path into a container with `-v /path:/path`; Docker does not manage it. A named volume is an object Docker manages (`docker volume ls/inspect/rm`) and that compose creates and shares between services. The subject requires named volumes with the data in `/home/login/data`, so this project declares two named volumes whose `driver_opts` bind them to that folder: Docker manages the volume objects, the bytes live where the subject wants them.

## Instructions

Prerequisites: Linux with Docker Engine, Docker Compose v2 and `make`; the line `127.0.0.1 mnahli.42.fr` in `/etc/hosts`; a file `srcs/.env` (see [DEV_DOC.md](DEV_DOC.md) for its variables).

```
make            # build the three images, create volumes and network, start the stack
make down       # stop and remove containers and network, keep the data
make re         # rebuild everything from scratch (removes the data)
```

Then open `https://mnahli.42.fr` and accept the self-signed certificate. The administration panel is at `https://mnahli.42.fr/wp-admin`.

More details: [USER_DOC.md](USER_DOC.md) (using the stack) and [DEV_DOC.md](DEV_DOC.md) (building and maintaining it).

## Resources

- Docker documentation: Dockerfile reference, `docker run`, networks, volumes, Compose file reference. https://docs.docker.com/
- MariaDB knowledge base: `mariadb-install-db`, server system variables, `bind-address`. https://mariadb.com/kb/
- WP-CLI commands: `core download`, `config create`, `core install`, `user create`. https://developer.wordpress.org/cli/commands/
- php-fpm configuration (`www.conf`, `listen`, `pm`). https://www.php.net/manual/en/install.fpm.configuration.php
- NGINX: `ngx_http_ssl_module`, `ngx_http_fastcgi_module`. https://nginx.org/en/docs/
- OpenSSL `req` manual page (self-signed certificates).
- Docker course on YouTube by Sami (networking, storage, Dockerfile chapters).

### How AI was used

Claude (Anthropic) was used as a tutor during the whole project, through Claude Code:

- Explaining concepts before each step (images and layers, PID 1 and `exec`, Docker networks and DNS, overlay storage and volumes, FastCGI, TLS) and answering questions, in English and Arabic.
- Drafting the two setup scripts (`srcs/requirements/mariadb/tools/init.sh`, `srcs/requirements/wordpress/tools/setup.sh`) and the three documentation files, after the Dockerfiles, configuration files, compose file and Makefile had been written by hand.
- Reviewing configuration files and reading command output and error messages with me.

Every file was typed, built and tested by me in WSL, one Dockerfile line at a time; AI output was checked against the subject and against real `docker` output before being kept.
