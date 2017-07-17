#!/bin/bash

if [[ $(id -u) -ne 0 ]]; then
    >&2 echo "NOTICE: This script operates on files owned by root."
    >&2 echo "Your sudo password may be required."
fi

HOMEBREW_PREFIX=@HOMEBREW_PREFIX@
PDNS_FORMULA="appdynamics/fermenter/pdns"

declare BREW_OWNER BREW_GROUP
eval `ls -l "$HOMEBREW_PREFIX/bin/brew" | awk '{printf("BREW_OWNER=%s;BREW_GROUP=%s;\n", $3, $4)}'`

PDNS_SERVER="$HOMEBREW_PREFIX/opt/pdns/sbin/pdns_server"

sudo chown $BREW_OWNER:$BREW_GROUP $PDNS_SERVER

sudo -u $BREW_OWNER brew update
sudo -u $BREW_OWNER brew upgrade "$PDNS_FORMULA"

sudo chown root:admin "$PDNS_SERVER"
