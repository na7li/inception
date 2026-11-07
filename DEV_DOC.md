# Developer documentation

## Repository layout

```
inception/
├── Makefile
├── README.md  USER_DOC.md  DEV_DOC.md
├── .gitignore                       # srcs/.env, *.key, *.crt
└── srcs/
    ├── docker-compose.yml
    ├── .env                         # credentials, not in git
    └── requirements/
        ├── mariadb/
        │   ├── Dockerfile
        │   ├── conf/50-server.cnf    # bind-address = 0.0.0.0
        │   └── tools/init.sh        # first-start setup, then exec mysqld
        ├── wordpress/
        │   ├── Dockerfile
        │   ├── conf/www.conf         # php-fpm pool, listen = 9000
        │   └── tools/setup.sh       # wait for mariadb, install with WP-CLI, exec php-fpm
        └── nginx/
            ├── Dockerfile            # also generates the self-signed certificate
            └── conf/default          # server block: 443, TLS 1.2/1.3, fastcgi_pass wordpress:9000
```

## Set up the environment from scratch

### Prerequisites

- Linux (developed in WSL2 on Windows 11, evaluated in a Debian VM). Docker Engine with Docker Compose v2 (`docker compose version`) and GNU `make`.
- Internet access during the build: the Dockerfiles install Debian packages and download WP-CLI; the first start downloads WordPress.
- The name `mnahli.42.fr` must resolve to the machine running the stack: add `127.0.0.1 mnahli.42.fr` to `/etc/hosts`.
- The login `mnahli` matters for the data path `/home/mnahli/data`; on another machine change `DATA` in the Makefile and the two `device:` lines in `srcs/docker-compose.yml`.

### Configuration files

| File | Purpose |
|---|---|
| `srcs/requirements/mariadb/conf/50-server.cnf` | Replaces Debian's server config; `bind-address = 0.0.0.0` so other containers can connect. |
| `srcs/requirements/wordpress/conf/www.conf` | php-fpm pool: user `www-data`, `listen = 9000` (TCP instead of a socket file), dynamic process manager with Debian's defaults. |
| `srcs/requirements/nginx/conf/default` | Copied over Debian's default site: removes port 80, serves `/var/www/html` on 443 with TLS 1.2/1.3, sends `.php` to `wordpress:9000` with `SCRIPT_FILENAME`. |
| `srcs/docker-compose.yml` | The three services, two named volumes bound to `/home/mnahli/data`, the `inception` bridge network. |

### Secrets

Create `srcs/.env` (never committed) with these twelve variables:

```
MYSQL_DATABASE=wordpress
MYSQL_USER=<db user>
MYSQL_PASSWORD=<db password>
MYSQL_ROOT_PASSWORD=<db root password>
WP_URL=https://mnahli.42.fr
WP_TITLE=Inception
WP_ADMIN_USER=<admin login, must not contain "admin">
WP_ADMIN_PASSWORD=<admin password>
WP_ADMIN_EMAIL=<admin email>
WP_USER=<second user login>
WP_USER_PASSWORD=<second user password>
WP_USER_EMAIL=<second user email>
```

Both setup scripts refuse to start if a variable they need is missing (`: "${VAR:?missing}"`), so a typo in a name shows up in `docker compose logs` as `VAR: missing`.

The TLS private key and certificate are generated inside the nginx image at build time (`openssl req -x509 … -subj "/CN=mnahli.42.fr"`, valid one year) and are not stored in the repository.

## Build and launch

```
make            # = make up: mkdir -p the data folders, then docker compose up -d --build
```

What `up -d --build` does, in order: builds `srcs-mariadb`, `srcs-wordpress`, `srcs-nginx` from the three Dockerfiles; creates the network `srcs_inception` and the volumes `srcs_mariadb_data`, `srcs_wordpress_data`; starts `mariadb`, then `wordpress` (`depends_on`), then `nginx`; detaches.

`depends_on` only orders the container starts. Readiness is handled in the scripts: `setup.sh` loops until `mariadb:3306` accepts a TCP connection before running WP-CLI.

First start: `init.sh` runs `mariadb-install-db` if the data folder is empty, starts a temporary server without networking, creates the database, the user and the root password, stops it, then `exec mysqld`. `setup.sh` downloads WordPress, writes `wp-config.php`, installs the site and creates the two users, then `exec php-fpm8.2 -F`. Later starts skip the setup: `init.sh` checks for the database folder, `setup.sh` for `wp-config.php`.

Other targets:

| Target | Runs |
|---|---|
| `make down` | `docker compose down` (containers and network removed, volumes kept) |
| `make stop` / `make start` | `docker compose stop` / `start` |
| `make logs` | `docker compose logs -f` |
| `make clean` | `docker compose down --rmi all` (also removes the three images) |
| `make fclean` | `docker compose down -v --rmi all` and removes `/home/mnahli/data/{mariadb,wordpress}` |
| `make re` | `fclean` then `all` |

All clean targets act only on this project's objects (through compose); no global `docker system prune`.

## Useful commands

```
docker compose -f srcs/docker-compose.yml ps                 # status of the three containers
docker compose -f srcs/docker-compose.yml logs -f wordpress  # one service's log
docker exec -it mariadb mariadb -u root -p                   # database shell as root
docker exec wordpress wp --allow-root --path=/var/www/html user list
docker exec -it nginx nginx -t                               # re-check the nginx config
docker top wordpress                                         # PID 1 must be php-fpm's master process
docker volume ls | grep srcs_                                # the two named volumes
docker volume inspect srcs_wordpress_data                    # shows the bound host path
docker network inspect srcs_inception                        # the three containers and their IPs
```

Rebuild one image after editing its Dockerfile or files:

```
docker compose -f srcs/docker-compose.yml up -d --build nginx
```

## Where the data is stored and how it persists

| Data | Container path | Host path | Volume |
|---|---|---|---|
| MariaDB databases | `/var/lib/mysql` | `/home/mnahli/data/mariadb` | `srcs_mariadb_data` |
| WordPress files (core, themes, uploads, `wp-config.php`) | `/var/www/html` | `/home/mnahli/data/wordpress` | `srcs_wordpress_data`, mounted in both `wordpress` and `nginx` |

The volumes are declared with `driver: local` and `driver_opts: type: none, o: bind, device: /home/mnahli/data/…`, so Docker manages the volume objects while the bytes live in the home folder the subject requires. The folders must exist before `docker compose up` (the Makefile creates them).

Persistence: `make down`, a reboot or a container crash (restart policy `unless-stopped`) never touch the host folders, and the setup scripts detect the existing data and skip installation. Only `make fclean` / `make re` delete them. The files inside belong to the container users (`mysql`, uid 100; `www-data`, uid 33), hence the `sudo rm -rf` in `fclean`.
