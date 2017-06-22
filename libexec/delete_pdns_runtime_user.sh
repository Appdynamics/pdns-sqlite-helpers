#!/bin/bash

declare PDNS_RUNTIME_USER \
    PDNS_RUNTIME_GROUP

source @SHAREDIR@/pdns-postgresql-helper-constants.sh

sudo dscl . -delete "/Users/$PDNS_RUNTIME_USER"
sudo dscl . -delete "/Groups/$PDNS_RUNTIME_GROUP"
