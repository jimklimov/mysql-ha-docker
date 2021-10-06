#!/bin/sh

# See proxysql-add-tester-user.sh for schema and user initialization for the test

CLUSTER_SQL_PORT='3306'
CLUSTER_TEST_USER='tester'
CLUSTER_TEST_PASS='Passw0rd123'

mysqlcmd() {
    docker-compose exec proxysql \
        mysql -u "${CLUSTER_TEST_USER}" -p"${CLUSTER_TEST_PASS}" \
        -h 127.0.0.1 -P"${CLUSTER_SQL_PORT}" -Dsandbox "$@"
}

sqlexec() {
    mysqlcmd -e "$@"
}

echo "=== Original data:"
sqlexec "SELECT * FROM t_rooms; SELECT * FROM t_workgroups";

echo ""
echo "CHECK INTERSECTIONS:"
echo ""

echo "=== LEFT JOIN t_workgroups into t_rooms (all rooms, and any workgroup data if present):"
sqlexec "SELECT room, t_rooms.id AS id, workgroup FROM t_rooms LEFT JOIN t_workgroups ON t_rooms.id = t_workgroups.id;"

# NOTE: Not all versions of MySQL had a RIGHT JOIN ability
echo "=== RIGHT JOIN t_rooms into t_workgroups (should be same as above, double-inversion):"
sqlexec "SELECT room, t_rooms.id AS id, workgroup FROM t_workgroups RIGHT JOIN t_rooms ON t_rooms.id = t_workgroups.id;"

echo "=== LEFT JOIN t_rooms into t_workgroups (all workgroups, and any room data if present):"
sqlexec "SELECT room, t_workgroups.id AS id, workgroup FROM t_workgroups LEFT JOIN t_rooms ON t_rooms.id = t_workgroups.id;"

echo "=== INNER JOIN t_rooms into t_workgroups (all rooms that have present workgroup data):"
sqlexec "SELECT room, t_rooms.id AS id, workgroup FROM t_workgroups INNER JOIN t_rooms ON t_rooms.id = t_workgroups.id;"

# NOTE: MySQL does not offer a (FULL) OUTER JOIN syntax; so there are tricks...
# https://dev.mysql.com/doc/refman/8.0/en/outer-join-simplification.html
# https://stackoverflow.com/questions/4796872/how-can-i-do-a-full-outer-join-in-mysql
