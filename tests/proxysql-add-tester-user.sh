#!/bin/sh

# This script adds user accounts into proxysql and into the database cluster
# for testing with a sandbox schema, injects that schema and data, and
# validates that the test user can access it and that replication worked.
#
# It uses the mysql client installed in the proxysql/mysqlmaster/mysqlslave
# docker containers respectively; no client is required on test runner itself.

# Predefined by docker-compose recipe files
CLUSTER_ADMIN_USER='root'
CLUSTER_ADMIN_PASS='password'
CLUSTER_SQL_PORT='3306'
CLUSTER_SQL_NETWORK='172.56.0.%'

PROXY_ADMIN_USER='admin'
PROXY_ADMIN_PASS='proxysql'
PROXY_SQL_PORT='6032'

# Will be created below
CLUSTER_TEST_USER='tester'
CLUSTER_TEST_PASS='Passw0rd123'

###################################################

echo "=== Add access for database cluster admin user '${CLUSTER_ADMIN_USER}' via proxy to make the test schema"
cat << EOF | docker-compose exec -T proxysql mysql -u "${PROXY_ADMIN_USER}" -p"${PROXY_ADMIN_PASS}" -h 127.0.0.1 -P"${PROXY_SQL_PORT}"
INSERT INTO mysql_users(username,password,default_hostgroup,default_schema,transaction_persistent) VALUES ('${CLUSTER_ADMIN_USER}', '${CLUSTER_ADMIN_PASS}', 10, 'mysql', 1);
SAVE MYSQL USERS TO DISK;
LOAD MYSQL USERS TO RUNTIME;
EOF

###################################################

echo "=== Add the schema and test data using the proxy"
cat "`dirname $0`"/schema.sql \
| docker-compose exec -T proxysql \
    mysql -u "${CLUSTER_ADMIN_USER}" -p"${CLUSTER_ADMIN_PASS}" \
    -h 127.0.0.1 -P"${CLUSTER_SQL_PORT}"

###################################################

echo "=== Add a user account which may use the proxysql for the test run in the sandbox"
cat << EOF | docker-compose exec -T proxysql mysql -u "${PROXY_ADMIN_USER}" -p"${PROXY_ADMIN_PASS}" -h 127.0.0.1 -P"${PROXY_SQL_PORT}"
INSERT INTO mysql_users(username,password,default_hostgroup,default_schema,transaction_persistent) VALUES ('${CLUSTER_TEST_USER}', '${CLUSTER_TEST_PASS}', 10, 'sandbox', 1);
SAVE MYSQL USERS TO DISK;
LOAD MYSQL USERS TO RUNTIME;
EOF

###################################################

echo "=== Add the same account in the database cluster for access from docker subnet"
docker-compose exec proxysql \
    mysql -u "${CLUSTER_ADMIN_USER}" -p"${CLUSTER_ADMIN_PASS}" \
    -h 127.0.0.1 -P"${CLUSTER_SQL_PORT}" -Dmysql -e \
"CREATE USER '${CLUSTER_TEST_USER}'@'${CLUSTER_SQL_NETWORK}' IDENTIFIED BY '${CLUSTER_TEST_PASS}';"

# Technically not needed as long as we use proxysql only - but below we check
# that replication worked. Also note that IPv4 '127.0.0.1' differs from what
# the server may see as 'localhost' so we add both entries.
echo "=== Add the same account in the database cluster for access from localhost of each server"
docker-compose exec proxysql \
    mysql -u "${CLUSTER_ADMIN_USER}" -p"${CLUSTER_ADMIN_PASS}" \
    -h 127.0.0.1 -P"${CLUSTER_SQL_PORT}" -Dmysql -e \
"CREATE USER '${CLUSTER_TEST_USER}'@'localhost' IDENTIFIED BY '${CLUSTER_TEST_PASS}';"

docker-compose exec proxysql \
    mysql -u "${CLUSTER_ADMIN_USER}" -p"${CLUSTER_ADMIN_PASS}" \
    -h 127.0.0.1 -P"${CLUSTER_SQL_PORT}" -Dmysql -e \
"CREATE USER '${CLUSTER_TEST_USER}'@'127.0.0.1' IDENTIFIED BY '${CLUSTER_TEST_PASS}';"

echo "=== Make sure privilege grants are enabled for the account in the database cluster"
for H in "${CLUSTER_SQL_NETWORK}" "localhost" "127.0.0.1" ; do
  docker-compose exec proxysql \
    mysql -u "${CLUSTER_ADMIN_USER}" -p"${CLUSTER_ADMIN_PASS}" \
    -h 127.0.0.1 -P"${CLUSTER_SQL_PORT}" -Dmysql -e \
"GRANT ALL PRIVILEGES ON sandbox.* TO '${CLUSTER_TEST_USER}'@'${H}';"
done

docker-compose exec proxysql \
    mysql -u "${CLUSTER_ADMIN_USER}" -p"${CLUSTER_ADMIN_PASS}" \
    -h 127.0.0.1 -P"${CLUSTER_SQL_PORT}" -Dmysql -e "
UPDATE mysql.user SET Grant_priv = 'Y' WHERE User = '${CLUSTER_TEST_USER}';
FLUSH PRIVILEGES;
"

echo "=== Check that database cluster test user exists"
docker-compose exec proxysql \
    mysql -u "${CLUSTER_ADMIN_USER}" -p"${CLUSTER_ADMIN_PASS}" \
    -h 127.0.0.1 -P"${CLUSTER_SQL_PORT}" -Dmysql -N -e \
    "SELECT * FROM user WHERE User = '${CLUSTER_TEST_USER}';"

docker-compose exec proxysql \
    mysql -u "${CLUSTER_ADMIN_USER}" -p"${CLUSTER_ADMIN_PASS}" \
    -h 127.0.0.1 -P"${CLUSTER_SQL_PORT}" -Dmysql -e \
    "SHOW GRANTS FOR '${CLUSTER_TEST_USER}'@'${CLUSTER_SQL_NETWORK}';"

docker-compose exec proxysql \
    mysql -u "${CLUSTER_ADMIN_USER}" -p"${CLUSTER_ADMIN_PASS}" \
    -h 127.0.0.1 -P"${CLUSTER_SQL_PORT}" -Dmysql -e \
    "SHOW GRANTS FOR '${CLUSTER_TEST_USER}'@'localhost';"

###################################################

echo "=== Check that the test user can access the schema via proxy:"
docker-compose exec proxysql \
    mysql -u "${CLUSTER_TEST_USER}" -p"${CLUSTER_TEST_PASS}" \
    -h 127.0.0.1 -P"${CLUSTER_SQL_PORT}" -Dsandbox -e \
    "SHOW TABLES;"

echo "=== Check that the test user can access the schema via cluster master instance:"
for H in 127.0.0.1 localhost ; do
  docker-compose exec mysqlmaster \
    mysql -u "${CLUSTER_TEST_USER}" -p"${CLUSTER_TEST_PASS}" \
    -h "$H" -P"${CLUSTER_SQL_PORT}" -Dsandbox -e \
    "SHOW TABLES;"
done

echo "=== Check that the test user can access the schema via cluster slave instance (and that replication happened):"
for H in 127.0.0.1 localhost ; do
  docker-compose exec mysqlslave \
    mysql -u "${CLUSTER_TEST_USER}" -p"${CLUSTER_TEST_PASS}" \
    -h "$H" -P"${CLUSTER_SQL_PORT}" -Dsandbox -e \
    "SHOW TABLES;"
done

###################################################

echo "=== Check that the test user can access the schema data via proxy:"
docker-compose exec proxysql \
    mysql -u "${CLUSTER_TEST_USER}" -p"${CLUSTER_TEST_PASS}" \
    -h 127.0.0.1 -P"${CLUSTER_SQL_PORT}" -Dsandbox -e \
    "SELECT * FROM t_rooms; SELECT * FROM t_workgroups;"
