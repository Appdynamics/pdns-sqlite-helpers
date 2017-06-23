# shell-friendly psql alias

PDNS_CFGDIR="@HOMEBREW_PREFIX@/etc/pdns"
PDNS_CFGNAME="pdns.conf"
# Use defaults from https://doc.powerdns.com/md/authoritative/backend-generic-postgresql/

PDNS_RUNTIME_USER=_pdns
PDNS_USER_ALIAS="pdns"
PDNS_RUNTIME_GROUP=_pdns
PDNS_GROUP_ALIAS="pdns"
PDNS_REALNAME="PowerDNS Runtime User"
# Listing User / Group IDs...
#   dscl . -list /Users UniqueID | sort -k 2 -n
#   dscl . -list /Groups UniqueID | sort -k 2 -n
# There is a hole in low-numbered UIDs / GIDs in Sierra from 101-199
# Assigning 199 to minimize chances of conflicts with other services.
PDNS_UNIQUE_ID=199
PDNS_PRIMARY_GID=199

PDNS_SQLITE_DB_DIR="@VARDIR@/pdns/db"
PDNS_SQLITE_FILENAME="$PDNS_SQLITE_DB_DIR/pdns.sqlite3"