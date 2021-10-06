DROP DATABASE IF EXISTS sandbox;
CREATE DATABASE IF NOT EXISTS sandbox CHARACTER SET utf8 COLLATE utf8_general_ci;

USE sandbox;

SET GLOBAL time_zone='+00:00';

DROP TABLE IF EXISTS t_rooms;
CREATE TABLE IF NOT EXISTS t_rooms(
    id                  INTEGER UNSIGNED        NOT NULL AUTO_INCREMENT,
    room                INTEGER UNSIGNED        NOT NULL,
    PRIMARY KEY(id)
);

DROP TABLE IF EXISTS t_workgroups;
CREATE TABLE IF NOT EXISTS t_workgroups(
    id                  INTEGER UNSIGNED        NOT NULL AUTO_INCREMENT,
    workgroup           INTEGER UNSIGNED        NOT NULL,
    PRIMARY KEY(id)
);

INSERT INTO t_rooms(room, id) VALUES (1, 100);
INSERT INTO t_rooms(room, id) VALUES (2, 101);
INSERT INTO t_rooms(room, id) VALUES (3, 105);

INSERT INTO t_workgroups(workgroup, id) VALUES (2, 100);
INSERT INTO t_workgroups(workgroup, id) VALUES (2, 101);
INSERT INTO t_workgroups(workgroup, id) VALUES (5, 102);
