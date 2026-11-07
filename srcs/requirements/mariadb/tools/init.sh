#!/bin/bash
set -e

: "${MYSQL_DATABASE:?missing}"
: "${MYSQL_USER:?missing}"
: "${MYSQL_PASSWORD:?missing}"
: "${MYSQL_ROOT_PASSWORD:?missing}"

chown -R mysql:mysql /var/lib/mysql

if [ ! -d "/var/lib/mysql/${MYSQL_DATABASE}" ]
then
    echo "[init] first start: setting up"
    if [ ! -d /var/lib/mysql/mysql ]
    then
        mariadb-install-db --user=mysql --datadir=/var/lib/mysql > /dev/null
    fi

    mysqld --user=mysql --skip-networking &
    pid=$!
    until mysqladmin ping --silent
    do
        sleep 1
    done

    mysql -u root <<SQL
CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';
ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
FLUSH PRIVILEGES;
SQL

    mysqladmin -u root -p"${MYSQL_ROOT_PASSWORD}" shutdown
    wait "$pid"
    echo "[init] database '${MYSQL_DATABASE}' and user '${MYSQL_USER}' created"
fi

echo "[init] starting MariaDB"
exec mysqld --user=mysql
