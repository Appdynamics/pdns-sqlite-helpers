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

DATE_TIMESTAMP=`date "+%Y%m%d-%H%M%S"`
PDNS_CONF="@ETCDIR@/pdns/pdns.conf"
PDNS_SQLITE_DB="@VARDIR@/pdns/db/pdns.sqlite3"
PDNS_SQLITE_DB_DIR="$(dirname "$PDNS_SQLITE_DB")"
# Use the brew sqlite3 rather than the "OS X" default
PATH="/usr/local/opt/sqlite/bin:$PATH"

# Everything about the DNS server config includng its database should be privileged or owned by _pdns

# rename $1 to $1.bak-$DATE_TIMESTAMP and keep it in the same directory
backup_file(){
    if [ -f "$1" ]; then
        if ! sudo mv "$1" "$1.bak-$DATE_TIMESTAMP"; then
            >&2 echo "Failed to rename '$1' to"
            >&2 echo "$1.bak-$DATE_TIMESTAMP"
            >&2 echo "Exiting."
            exit 2
        fi
    fi
}

if ! [ -d "$PDNS_SQLITE_DB_DIR" ]; then
    if ! mkdir -p "$PDNS_SQLITE_DB_DIR"; then
        >&2 echo "Unable to create '$PDNS_SQLITE_DB_DIR'"
        >&2 echo "Exiting."
        exit 1
    fi
fi
backup_file "$PDNS_CONF"
backup_file "$PDNS_SQLITE_DB"

# create new pdns.sqlite3 with pdns schema
sudo sqlite3 "$PDNS_SQLITE_DB" <<PDNS_SQLITE_SCHEMA
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
sudo sqlite3 "$PDNS_SQLITE_DB" <<PDNS_RFC1912_RECORDS
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

# create new pdns.conf
sudo cat > "$PDNS_CONF" <<PDNS_CONFIG_CONTENTS
# Copyright 2017, AppDynamics LLC and its affiliates
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


# See https://doc.powerdns.com/md/authoritative/settings/ for a complete
# reference on PowerDNS configuration options

# Use the 'sqlite3' backend.
# See https://doc.powerdns.com/md/authoritative/ for information on other
# backends
launch=gsqlite3

setuid=_sandbox
setgid=_sandbox

# See https://doc.powerdns.com/md/authoritative/backend-generic-sqlite/ for a
# complete reference on the SQLite backend
gsqlite3-database="$PDNS_SQLITE_DB"
gsqlite3-pragma-foreign-keys=1
PDNS_CONFIG_CONTENTS