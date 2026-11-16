# Developer documentation

## Files of the project

```
Makefile                      build, start, stop, clean
README.md  USER_DOC.md  DEV_DOC.md
.gitignore                    keeps srcs/.env out of git
srcs/docker-compose.yml       the three services, two volumes, one network
srcs/.env                     names and passwords (not in git)
srcs/requirements/mariadb/    Dockerfile, conf/50-server.cnf, tools/init.sh
srcs/requirements/wordpress/  Dockerfile, conf/www.conf, tools/setup.sh
srcs/requirements/nginx/      Dockerfile, conf/default
```

## Set up the environment from scratch

### What you need

- Linux with Docker, Docker Compose (`docker compose version`) and `make`. Tested in a Debian 12 virtual machine.
- Internet during the build: the Dockerfiles install Debian packages, and the first start downloads WordPress.
- The line `127.0.0.1 mnahli.42.fr` in `/etc/hosts`, so the name `mnahli.42.fr` points to this machine.
- The data is stored in `/home/mnahli/data`. With another login, change `DATA` in the Makefile and the two `device:` lines in `srcs/docker-compose.yml`.

### Configuration files

| File | What it does |
|---|---|
| `srcs/requirements/mariadb/conf/50-server.cnf` | Tells MariaDB to accept connections from other containers (`bind-address = 0.0.0.0`). |
| `srcs/requirements/wordpress/conf/www.conf` | Tells php-fpm to listen on port 9000 and to run as the user `www-data`. |
| `srcs/requirements/nginx/conf/default` | Tells NGINX to listen on port 443 with TLS 1.2 and 1.3, to serve the files in `/var/www/html`, and to send `.php` requests to `wordpress:9000`. |
| `srcs/docker-compose.yml` | Describes the three services, the two volumes and the network `inception`. |

### Secrets

Create the file `srcs/.env` with these twelve variables. This file is never committed to git.

```
MYSQL_DATABASE=wordpress
MYSQL_USER=<database user>
MYSQL_PASSWORD=<database password>
MYSQL_ROOT_PASSWORD=<database root password>
WP_URL=https://mnahli.42.fr
WP_TITLE=Inception
WP_ADMIN_USER=<admin login, without the word "admin">
WP_ADMIN_PASSWORD=<admin password>
WP_ADMIN_EMAIL=<admin email>
WP_USER=<second user login>
WP_USER_PASSWORD=<second user password>
WP_USER_EMAIL=<second user email>
```

If a variable is missing, the container stops and its log shows the name of the variable, for example `MYSQL_USER: missing`.

The TLS certificate is created inside the nginx image during the build. It is not stored in the repository.

## Build and launch

```
make
```

`make` creates the two data folders, then runs `docker compose up -d --build`. This command:

1. builds the three images `mariadb`, `wordpress` and `nginx` from the Dockerfiles;
2. creates the network `srcs_inception` and the volumes `srcs_mariadb_data` and `srcs_wordpress_data`;
3. starts the containers in this order: `mariadb`, `wordpress`, `nginx`.

On the first start, `init.sh` creates the database, the database user and the root password. Then `setup.sh` waits until MariaDB answers on port 3306, downloads WordPress, installs the site and creates the two WordPress users.

On later starts, the scripts find the existing data and only start the servers.

Other targets:

| Target | What it runs |
|---|---|
| `make down` | `docker compose down`: removes the containers and the network, keeps the data |
| `make stop` / `make start` | `docker compose stop` / `docker compose start` |
| `make logs` | `docker compose logs -f` |
| `make clean` | `docker compose down --rmi all`: also removes the three images |
| `make fclean` | `docker compose down -v --rmi all`, then deletes `/home/mnahli/data/mariadb` and `/home/mnahli/data/wordpress` |
| `make re` | `fclean`, then `all` |

The clean targets remove only the objects of this project.

## Useful commands

```
docker compose -f srcs/docker-compose.yml ps                 # state of the three containers
docker compose -f srcs/docker-compose.yml logs -f wordpress  # log of one service
docker exec -it mariadb mariadb -u root -p                   # database shell as root
docker exec -it wordpress bash                               # shell inside a container
docker exec nginx nginx -t                                   # check the nginx configuration
docker top wordpress                                         # processes of a container
docker volume ls                                             # the two volumes
docker volume inspect srcs_wordpress_data                    # shows the host folder of a volume
docker network inspect srcs_inception                        # the three containers and their IP addresses
```

Running `make` a second time does not recreate anything: Docker finds the images and the containers unchanged and keeps them. The second command above proves it, because the containers keep their old age (for example `Up 20 minutes`).

After a change in a Dockerfile or a configuration file:

```
make down && make
```

## Where the data is stored and how it persists

| Data | Folder in the container | Folder on the host | Volume |
|---|---|---|---|
| Database | `/var/lib/mysql` in `mariadb` | `/home/mnahli/data/mariadb` | `srcs_mariadb_data` |
| WordPress files | `/var/www/html` in `wordpress` and `nginx` | `/home/mnahli/data/wordpress` | `srcs_wordpress_data` |

The two volumes are named volumes. Their options in `srcs/docker-compose.yml` (`driver_opts`) tell Docker to store the files in `/home/mnahli/data`, as the subject asks.

The data stays after `make down`, after a reboot and after a container crash, because the files are on the host and not inside the containers. Only `make fclean` and `make re` delete the data.

## Check the rules of the subject

Run these commands from the root of the repository. Each block checks one rule.

```
# 1. Every image starts from debian:bookworm, no "latest" tag
grep -n 'FROM' srcs/requirements/*/Dockerfile
grep -rn 'latest' srcs/

# 2. No fake process to keep a container alive
grep -rnE 'tail -f|sleep infinity|while true' srcs/
grep -n 'CMD\|ENTRYPOINT' srcs/requirements/*/Dockerfile

# 3. No host network and no links
grep -nE 'network_mode|links:|--link' srcs/docker-compose.yml Makefile
grep -n -A2 '^networks' srcs/docker-compose.yml

# 4. Only nginx opens a port, and it is 443
grep -n -B4 -A1 'ports:' srcs/docker-compose.yml

# 5. No credentials in git
git ls-files | grep -iE '\.env|secret'
git grep -nF -f <(grep PASSWORD srcs/.env | cut -d= -f2-)

# 6. Programs started in the background, and the last line of each script
grep -nE '&\s*$' srcs/requirements/*/tools/*.sh
tail -n1 srcs/requirements/*/tools/*.sh

# 7. PID 1 of each container is the real server
docker top mariadb
docker top wordpress
docker top nginx
```

What a correct result looks like:

| Check | Correct result |
|---|---|
| 1 | three lines `FROM debian:bookworm`, and nothing for `latest` |
| 2 | nothing for the first command; the CMD lines are `init.sh`, `setup.sh` and `nginx -g "daemon off;"` |
| 3 | nothing for the first command; the network `inception` with `driver: bridge` |
| 4 | `ports:` only under `nginx`, with `"443:443"` |
| 5 | nothing for both commands: `.env` is not in git, and no password from `.env` is written in a tracked file |
| 6 | one line, `init.sh:19`: the temporary `mysqld` used only to create the database; the last lines are `exec mysqld --user=mysql` and `exec php-fpm8.2 -F` |
| 7 | PID 1 is `mysqld`, `php-fpm` and `nginx`, never `bash`, `sleep` or `tail` |

The two `until … sleep 1` loops in the scripts are not infinite loops. They wait a few seconds for MariaDB to be ready, then the script continues and ends with `exec`.
