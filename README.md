*This project has been created as part of the 42 curriculum by mnahli.*

# Inception

## Description

The goal of Inception is to build a small web infrastructure with Docker, inside a virtual machine. The result is a WordPress website at `https://mnahli.42.fr`.

The project has three services. Each service runs in its own container, and each container is built from my own Dockerfile on `debian:bookworm`.

| Service | Container | Job |
|---|---|---|
| NGINX | `nginx` | The only entry point. It listens on port 443 with TLS 1.2 and 1.3, and sends PHP requests to WordPress. |
| WordPress + php-fpm | `wordpress` | Runs the WordPress code. It listens on port 9000, reachable only from the other containers. |
| MariaDB | `mariadb` | The database. It listens on port 3306, reachable only from the other containers. |

### Use of Docker and sources included

Docker builds one image per service from a Dockerfile, and Docker Compose starts the three containers together with their network and volumes. The Makefile runs Docker Compose.

```
Makefile                      build, start, stop, clean
srcs/docker-compose.yml       the three services, two volumes, one network
srcs/.env                     names and passwords (not in git)
srcs/requirements/mariadb/    Dockerfile, conf/50-server.cnf, tools/init.sh
srcs/requirements/wordpress/  Dockerfile, conf/www.conf, tools/setup.sh
srcs/requirements/nginx/      Dockerfile, conf/default
```

### Main design choices

- **One service per container.** The main process of each container is the server itself (`mysqld`, `php-fpm`, `nginx`), so `docker stop` stops it cleanly.
- **Setup runs only once.** On the first start, `init.sh` creates the database and its users, and `setup.sh` installs WordPress. On later starts they find the existing data and only start the server.
- **No passwords in the images or in git.** All names and passwords come from `srcs/.env` when the containers start.
- **Debian bookworm**, the penultimate stable version, and no `latest` tag.
- **Data stays on the host** in `/home/mnahli/data`, so it survives when containers are removed.

### Virtual Machines vs Docker

A virtual machine runs a complete operating system with its own kernel. It is heavy: gigabytes on disk and a long boot. A Docker container is only a group of isolated processes that use the kernel of the host. It is light and starts in about one second. In this project the containers run inside a Debian virtual machine.

### Secrets vs Environment Variables

Environment variables are the simple way to give values to a container. Any process in the container can read them, and `docker inspect` shows them. Docker secrets give each value as a file that only the chosen service can read, which is safer. This project uses environment variables from the file `srcs/.env`, and this file is never committed to git.

### Docker Network vs Host Network

With the host network, a container uses the network of the host directly: every port it opens is open on the host, and containers are not separated from each other. With a Docker network, each container has its own IP address, containers find each other by name (`mariadb`, `wordpress`), and only the published ports are reachable from outside. This project uses one Docker bridge network named `inception` and publishes only port 443. The subject forbids the host network.

### Docker Volumes vs Bind Mounts

A bind mount connects a folder of the host directly to a folder in a container; Docker does not manage it. A volume is an object that Docker creates and manages (`docker volume ls`, `docker volume inspect`). The subject asks for named volumes with the data in `/home/login/data`. This project has two named volumes, `mariadb_data` and `wordpress_data`, and their files are stored in `/home/mnahli/data/mariadb` and `/home/mnahli/data/wordpress`.

## Instructions

Requirements: Linux with Docker, Docker Compose and `make`; the line `127.0.0.1 mnahli.42.fr` in `/etc/hosts`; the file `srcs/.env` (its variables are listed in [DEV_DOC.md](DEV_DOC.md)).

```
make            # build the images and start everything
make down       # stop and remove the containers, keep the data
make re         # delete everything, data included, and build again
```

Then open `https://mnahli.42.fr` and accept the self-signed certificate. The administration panel is at `https://mnahli.42.fr/wp-admin`.

More details are in [USER_DOC.md](USER_DOC.md) and [DEV_DOC.md](DEV_DOC.md).

## Resources

- Docker documentation: https://docs.docker.com/
- NGINX documentation: https://nginx.org/en/docs/
- MariaDB documentation: https://mariadb.com/kb/
- WP-CLI commands: https://developer.wordpress.org/cli/commands/
- php-fpm configuration: https://www.php.net/manual/en/install.fpm.configuration.php
- A Docker course on YouTube (networks, storage, Dockerfile).

### How AI was used

I used an AI assistant as a tutor during the project:

- to explain Docker ideas before each step and to answer my questions;
- to help me read error messages and command output;
- to write the first version of the two scripts (`init.sh`, `setup.sh`) and of the three documentation files, which I then read and tested.

I wrote the Dockerfiles, the configuration files, `docker-compose.yml` and the Makefile myself, and I built and tested everything.
