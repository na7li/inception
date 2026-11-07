#!/bin/bash
set -e

: "${MYSQL_DATABASE:?missing}"
: "${MYSQL_USER:?missing}"
: "${MYSQL_PASSWORD:?missing}"
: "${WP_URL:?missing}"
: "${WP_TITLE:?missing}"
: "${WP_ADMIN_USER:?missing}"
: "${WP_ADMIN_PASSWORD:?missing}"
: "${WP_ADMIN_EMAIL:?missing}"
: "${WP_USER:?missing}"
: "${WP_USER_PASSWORD:?missing}"
: "${WP_USER_EMAIL:?missing}"

mkdir -p /var/www/html
cd /var/www/html

until (echo > /dev/tcp/mariadb/3306) 2> /dev/null
do
    echo "[setup] waiting for mariadb:3306"
    sleep 1
done

if [ ! -f wp-config.php ]
then
    echo "[setup] first start: installing WordPress"
    wp core download --allow-root
    wp config create --allow-root --dbhost=mariadb --dbname="$MYSQL_DATABASE" --dbuser="$MYSQL_USER" --dbpass="$MYSQL_PASSWORD"
    wp core install --allow-root --url="$WP_URL" --title="$WP_TITLE" --admin_user="$WP_ADMIN_USER" --admin_password="$WP_ADMIN_PASSWORD" --admin_email="$WP_ADMIN_EMAIL" --skip-email
    wp user create --allow-root "$WP_USER" "$WP_USER_EMAIL" --role=author --user_pass="$WP_USER_PASSWORD"
    chown -R www-data:www-data /var/www/html
    echo "[setup] WordPress installed"
fi

echo "[setup] starting php-fpm"
exec php-fpm8.2 -F
