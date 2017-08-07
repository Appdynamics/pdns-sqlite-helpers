#!/bin/bash

# Copyright 2017, AppDynamics LLC and its affiliates
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# 'declare' variables we're sourcing from @SHAREDIR@/pdns-sqlite-helper-constants.sh
# to keep the IDE happy
declare PASSWORD_NCHARS \
    PDNS_CFGDIR \
    PDNS_CFGNAME \
    PDNS_RUNTIME_USER \
    PDNS_RUNTIME_GROUP \
    PDNS_SQLITE_DB_DIR \
    PDNS_SQLITE_FILENAME

source @SHAREDIR@/pdns-sqlite-helper-constants.sh

USAGE="\
init-pdns-sqlite3-db-and-config.sh [options]

Creates a new PowerDNS configuration and SQLite database.

Options:
    -C <dir>        Path to alternate location for pdns.conf
                    Default: $PDNS_CFGDIR
    -D <path>       Path to alternate location for the PowerDNS sqlite backend
                    database file. Default: $PDNS_SQLITE_DB_DIR/$PDNS_SQLITE_FILENAME
    -p <1-65535>    Alternate port for DNS queries.  Default: 53
    -H <1-65535>    Alternate HTTP server port number: Default 8001
    -m <email addr> Default hostmaster email used by PowerDNS.
    -n              No sudo. Do not use 'sudo' to change the ownership of
                    config files to root and sqlite file to $PDNS_RUNTIME_USER.
    -h              Print this help message and exit.
"

# TODO: RFC822, sections 3.3 and 6 actually allow for many more special
# characters in the "local-part" token, but supporting all of them takes us to
# the land of diminishing returns.  If we need to support any RFC822-compliant
# email address, we need to reimplement this tool in a different language that
# has available escape-for-JSON library routines
#
# $1: email address to check for safety.
is_safe_email(){
    [ ${#@} -eq 1 ] && [[ $1 =~ ^[-A-Za-z0-9._+]+@([-A-Za-z0-9]{2,}\.)+$ ]]
}

DATE_TIMESTAMP=`date "+%Y%m%d-%H%M%S"`
DEFAULT_SOA_MAIL=`whoami`@`hostname -s`.corp.appdynamics.com

# Alias the brew sqlite3 rather using than the "OS X" default
SQLITE="@SQLITE_BINARY@"

# renames $1 to $1.bak-$DATE_TIMESTAMP, and keeps it in the same directory
# $2: optional ownership spec i.e. 'user' or 'user:group'
backup_file(){
    local SUDO=
    if [ -n "$2" ]; then
        SUDO=sudo
    fi
    if [ -f "$1" ]; then
        DST="$1.bak-$DATE_TIMESTAMP"
        if ! $SUDO mv "$1" "$DST"; then
            >&2 echo "Failed to rename '$1' to"
            >&2 echo "$DST"
            >&2 echo "Exiting."
            exit 2
        fi
        if [ -n "$2" ]; then
            sudo chown "$2" "$DST"
        fi
    fi
}

DNS_PORT=53
HTTP_PORT=8001
SUDO_PDNS="sudo -u $PDNS_RUNTIME_USER"
SUDO_ROOT="sudo"
CFG_OWNERSHIP_SPEC=root:admin
SQLITE_FILE_OWNERSHIP_SPEC=$PDNS_RUNTIME_USER:$PDNS_RUNTIME_GROUP
SET_UID_GID="setuid=$PDNS_RUNTIME_USER
setgid=$PDNS_RUNTIME_GROUP"

input_errors=0
while getopts ":C:D:p:H:nh" flag; do
    case $flag in
        C)
            PDNS_CFGDIR="$OPTARG"
        ;;
        D)
            PDNS_SQLITE_DB_DIR=$(dirname "$OPTARG")
            PDNS_SQLITE_FILENAME=$(basename "$OPTARG")
        ;;
        p)
            if test "$OPTARG" -ge 1 2>/dev/null && test "$OPTARG" -le 65535 2>/dev/null; then
                DNS_PORT=$OPTARG
            else
                >&2 echo "DNS port argument must be an integer between 1 and 65535"
                ((input_errors++))
            fi
        ;;
        H)
            if test "$OPTARG" -ge 1 2>/dev/null && test "$OPTARG" -le 65535 2>/dev/null; then
                HTTP_PORT=$OPTARG
            else
                >&2 echo "HTTP port argument must be an integer between 1 and 65535"
                ((input_errors++))
            fi
        ;;
        m)
            if is_safe_email "$OPTARG"; then
                DEFAULT_SOA_MAIL=$OPTARG
            else
                >&2 echo "Default hostmaster email is not a safely formatted email address."
                ((input_errors++))
            fi
        ;;
        n)
            SUDO_PDNS=
            SUDO_ROOT=
            CFG_OWNERSHIP_SPEC=
            SQLITE_FILE_OWNERSHIP_SPEC=
            SET_UID_GID=
        ;;
        *)
            >&2 echo "-$OPTARG flag not supported."
            ((input_errors++))
        ;;
    esac
done

if [ $input_errors -gt 0 ]; then
    >&2 echo "$USAGE"
    exit 1
fi


if ! [ -d "$PDNS_CFGDIR" ]; then
    if ! mkdir -p "$PDNS_CFGDIR"; then
        >&2 echo "Unable to create '$PDNS_CFGDIR'"
        >&2 echo "Exiting."
        exit 2
    fi
fi

if ! [ -d "$PDNS_SQLITE_DB_DIR" ]; then
    if ! mkdir -p "$PDNS_SQLITE_DB_DIR"; then
        >&2 echo "Unable to create '$PDNS_SQLITE_DB_DIR'"
        >&2 echo "Exiting."
        exit 3
    fi
fi

backup_file "$PDNS_CFGDIR/$PDNS_CFGNAME" $CFG_OWNERSHIP_SPEC
backup_file "$PDNS_SQLITE_DB_DIR/$PDNS_SQLITE_FILENAME" $SQLITE_FILE_OWNERSHIP_SPEC

if [ -n "$SUDO_PDNS" ]; then
    sudo chown "$PDNS_RUNTIME_USER:$PDNS_RUNTIME_GROUP" "$PDNS_SQLITE_DB_DIR"
fi

if [ -n "$SUDO_ROOT" ]; then
    sudo chown root:admin "$PDNS_CFGDIR"
fi

# create new pdns.sqlite3 with pdns schema
$SUDO_PDNS bash -c "'$SQLITE' '$PDNS_SQLITE_DB_DIR/$PDNS_SQLITE_FILENAME'" <<PDNS_SQLITE_SCHEMA
PRAGMA foreign_keys = 1;

CREATE TABLE domains (
  id                    INTEGER PRIMARY KEY,
  name                  VARCHAR(255) NOT NULL COLLATE NOCASE,
  master                VARCHAR(128) DEFAULT NULL,
  last_check            INTEGER DEFAULT NULL,
  type                  VARCHAR(6) NOT NULL,
  notified_serial       INTEGER DEFAULT NULL,
  account               VARCHAR(40) DEFAULT NULL
);

CREATE UNIQUE INDEX name_index ON domains(name);


CREATE TABLE records (
  id                    INTEGER PRIMARY KEY,
  domain_id             INTEGER DEFAULT NULL,
  name                  VARCHAR(255) DEFAULT NULL,
  type                  VARCHAR(10) DEFAULT NULL,
  content               VARCHAR(65535) DEFAULT NULL,
  ttl                   INTEGER DEFAULT NULL,
  prio                  INTEGER DEFAULT NULL,
  change_date           INTEGER DEFAULT NULL,
  disabled              BOOLEAN DEFAULT 0,
  ordername             VARCHAR(255),
  auth                  BOOL DEFAULT 1,
  FOREIGN KEY(domain_id) REFERENCES domains(id) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE INDEX rec_name_index ON records(name);
CREATE INDEX nametype_index ON records(name,type);
CREATE INDEX domain_id ON records(domain_id);
CREATE INDEX orderindex ON records(ordername);


CREATE TABLE supermasters (
  ip                    VARCHAR(64) NOT NULL,
  nameserver            VARCHAR(255) NOT NULL COLLATE NOCASE,
  account               VARCHAR(40) NOT NULL
);

CREATE UNIQUE INDEX ip_nameserver_pk ON supermasters(ip, nameserver);


CREATE TABLE comments (
  id                    INTEGER PRIMARY KEY,
  domain_id             INTEGER NOT NULL,
  name                  VARCHAR(255) NOT NULL,
  type                  VARCHAR(10) NOT NULL,
  modified_at           INT NOT NULL,
  account               VARCHAR(40) DEFAULT NULL,
  comment               VARCHAR(65535) NOT NULL,
  FOREIGN KEY(domain_id) REFERENCES domains(id) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE INDEX comments_domain_id_index ON comments (domain_id);
CREATE INDEX comments_nametype_index ON comments (name, type);
CREATE INDEX comments_order_idx ON comments (domain_id, modified_at);


CREATE TABLE domainmetadata (
 id                     INTEGER PRIMARY KEY,
 domain_id              INT NOT NULL,
 kind                   VARCHAR(32) COLLATE NOCASE,
 content                TEXT,
 FOREIGN KEY(domain_id) REFERENCES domains(id) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE INDEX domainmetaidindex ON domainmetadata(domain_id);


CREATE TABLE cryptokeys (
 id                     INTEGER PRIMARY KEY,
 domain_id              INT NOT NULL,
 flags                  INT NOT NULL,
 active                 BOOL,
 content                TEXT,
 FOREIGN KEY(domain_id) REFERENCES domains(id) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE INDEX domainidindex ON cryptokeys(domain_id);


CREATE TABLE tsigkeys (
 id                     INTEGER PRIMARY KEY,
 name                   VARCHAR(255) COLLATE NOCASE,
 algorithm              VARCHAR(50) COLLATE NOCASE,
 secret                 VARCHAR(255)
);

CREATE UNIQUE INDEX namealgoindex ON tsigkeys(name, algorithm);
PDNS_SQLITE_SCHEMA

# feed RFC1912, section 4.1 local domain information into pdns schema
$SUDO_PDNS bash -c "sqlite3 '$PDNS_SQLITE_DB_DIR/$PDNS_SQLITE_FILENAME'" <<PDNS_RFC1912_RECORDS
insert into domains (name,type) values ('0.in-addr.arpa','NATIVE');
insert into records (domain_id, name, type,content,ttl,prio,disabled) select id ,'0.in-addr.arpa', 'SOA', 'localhost root.localhost 1 604800 86400 2419200 604800', 604800, 0, 0 from domains where name='0.in-addr.arpa';
insert into records (domain_id, name, type,content,ttl,prio,disabled) select id ,'0.in-addr.arpa', 'NS', 'localhost', 604800, 0, 0 from domains where name='0.in-addr.arpa';
insert into domains (name,type) values ('127.in-addr.arpa','NATIVE');
insert into records (domain_id, name, type,content,ttl,prio,disabled) select id ,'127.in-addr.arpa', 'SOA', 'localhost root.localhost 1 604800 86400 2419200 604800', 604800, 0, 0 from domains where name='127.in-addr.arpa';
insert into records (domain_id, name, type,content,ttl,prio,disabled) select id ,'127.in-addr.arpa', 'NS', 'localhost', 604800, 0, 0 from domains where name='127.in-addr.arpa';
insert into records (domain_id, name, type,content,ttl,prio,disabled) select id ,'1.0.0.127.in-addr.arpa', 'PTR', 'localhost', 604800, 0, 0 from domains where name='127.in-addr.arpa';
insert into domains (name,type) values ('255.in-addr.arpa','NATIVE');
insert into records (domain_id, name, type,content,ttl,prio,disabled) select id ,'255.in-addr.arpa', 'SOA', 'localhost root.localhost 1 604800 86400 2419200 604800', 604800, 0, 0 from domains where name='255.in-addr.arpa';
insert into records (domain_id, name, type,content,ttl,prio,disabled) select id ,'255.in-addr.arpa', 'NS', 'localhost', 604800, 0, 0 from domains where name='255.in-addr.arpa';
insert into domains (name,type) values ('localhost','NATIVE');
insert into records (domain_id, name, type,content,ttl,prio,disabled) select id ,'localhost', 'SOA', 'localhost root.localhost 2 604800 86400 2419200 604800', 604800, 0, 0 from domains where name='localhost';
insert into records (domain_id, name, type,content,ttl,prio,disabled) select id ,'localhost', 'NS', 'localhost', 604800, 0, 0 from domains where name='localhost';
insert into records (domain_id, name, type,content,ttl,prio,disabled) select id ,'localhost', 'A', '127.0.0.1', 604800, 0, 0 from domains where name='localhost';
insert into records (domain_id, name, type,content,ttl,prio,disabled) select id ,'localhost', 'AAAA', '::1', 604800, 0, 0 from domains where name='localhost';
PDNS_RFC1912_RECORDS

$SUDO_ROOT touch "$PDNS_CFGDIR/$PDNS_CFGNAME"
$SUDO_ROOT chmod 644 "$PDNS_CFGDIR/$PDNS_CFGNAME"
$SUDO_ROOT bash -c "cat > \"$PDNS_CFGDIR/$PDNS_CFGNAME\"" <<PDNS_CONFIG_CONTENTS
# See https://doc.powerdns.com/md/authoritative/settings/ for a complete
# reference on PowerDNS configuration options

# Use the 'sqlite3' backend.
# See https://doc.powerdns.com/md/authoritative/ for information on other
# backends
launch=gsqlite3

local-port=$DNS_PORT

$SET_UID_GID

default-soa-mail=$DEFAULT_SOA_MAIL

webserver=yes
webserver-address=127.0.0.1
webserver-port=$HTTP_PORT
webserver-password=$(cat /dev/urandom | LC_CTYPE=C tr -dc 'a-zA-Z0-9' | head -c $PASSWORD_NCHARS)
webserver-print-arguments=no
api=yes

# See https://doc.powerdns.com/md/authoritative/backend-generic-sqlite/ for a
# complete reference on the SQLite backend
gsqlite3-database=$PDNS_SQLITE_DB_DIR/$PDNS_SQLITE_FILENAME
gsqlite3-pragma-foreign-keys=1

include-dir=$PDNS_CFGDIR/$PDNS_CFGNAME.d
PDNS_CONFIG_CONTENTS

# prevent API key from being read by anybody but root to minimize attack surface
PDNS_CFG_INCLUDE_DIR="$PDNS_CFGDIR/$PDNS_CFGNAME.d/"
$SUDO_PDNS mkdir "$PDNS_CFG_INCLUDE_DIR"
API_KEY_FILE="$PDNS_CFG_INCLUDE_DIR/api-key.conf"
$SUDO_ROOT touch "$API_KEY_FILE"
$SUDO_ROOT chmod 600 "$API_KEY_FILE"
$SUDO_ROOT bash -c "cat > \"$API_KEY_FILE\"" <<API_KEY
api-key=$(cat /dev/urandom | LC_CTYPE=C tr -dc 'a-zA-Z0-9' | head -c $PASSWORD_NCHARS)
API_KEY
