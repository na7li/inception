# User documentation

## What the stack provides

Three services, each in its own container:

| Service | What it does | Reachable from |
|---|---|---|
| `nginx` | The web server. Answers `https://mnahli.42.fr` on port 443 with TLS. | Your browser |
| `wordpress` | WordPress, the website itself, run by php-fpm. | nginx only (port 9000, internal) |
| `mariadb` | The database that stores posts, pages, users and settings. | wordpress only (port 3306, internal) |

Nothing answers on `http://` (port 80); only HTTPS is served.

## Start and stop

All commands run from the repository root (the folder with the `Makefile`).

| Command | Effect |
|---|---|
| `make` | Build the images if needed and start the three containers. The first start takes about one minute (WordPress is downloaded and installed). |
| `make down` | Stop and remove the containers. The website data is kept; the next `make` brings the site back as it was. |
| `make stop` / `make start` | Pause and resume the containers without removing them. |
| `make re` | Remove everything, including the data, and start from scratch. The site is reinstalled with the accounts from `srcs/.env`. |

## Access the website and the administration panel

1. Make sure your computer resolves the site name: the line `127.0.0.1 mnahli.42.fr` must be in `/etc/hosts` (Linux) or `C:\Windows\System32\drivers\etc\hosts` (Windows).
2. Open `https://mnahli.42.fr`. The browser warns that the certificate is not trusted: the certificate is self-signed, which is expected for this project. Click "Advanced" then "Proceed".
3. The administration panel is at `https://mnahli.42.fr/wp-admin`. Log in with the administrator account (see below).

Two accounts exist after installation: an administrator (can do everything) and a second user with the *author* role (can write posts).

## Locate and manage credentials

All credentials live in one file, `srcs/.env`, which is **not** part of the git repository and must never be committed or shared.

| Variable | What it is |
|---|---|
| `MYSQL_DATABASE`, `MYSQL_USER`, `MYSQL_PASSWORD` | The WordPress database and the account WordPress uses to reach it |
| `MYSQL_ROOT_PASSWORD` | The database root password (root cannot log in without it) |
| `WP_URL`, `WP_TITLE` | The site address and title |
| `WP_ADMIN_USER`, `WP_ADMIN_PASSWORD`, `WP_ADMIN_EMAIL` | The WordPress administrator (the login must not contain "admin") |
| `WP_USER`, `WP_USER_PASSWORD`, `WP_USER_EMAIL` | The second WordPress user |

To change a password: edit `srcs/.env`, then run `make re` (the accounts are created at the first start only). Changing a WordPress password without reinstalling is also possible from the administration panel, Users menu.

## Check that the services are running

```
docker compose -f srcs/docker-compose.yml ps
```

The three containers `mariadb`, `wordpress` and `nginx` must show `Up`. To follow what they print:

```
make logs
```

Quick checks of each service:

| Check | Command | Expected |
|---|---|---|
| Website answers | `curl -k -I https://mnahli.42.fr` | `HTTP/1.1 200 OK`, `Server: nginx` |
| Port 80 is closed | `curl -I http://mnahli.42.fr` | `Connection refused` |
| WordPress installed | `docker exec wordpress wp core is-installed --allow-root --path=/var/www/html && echo OK` | `OK` |
| Database login works | `docker exec -it mariadb mariadb -u <MYSQL_USER> -p<MYSQL_PASSWORD> <MYSQL_DATABASE> -e "SHOW TABLES;"` | the list of WordPress tables |
| Root without password refused | `docker exec -it mariadb mariadb -u root` | `ERROR 1045 (28000): Access denied` |
