#!/bin/bash

declare PDNS_RUNTIME_USER \
    PDNS_USER_RECORD_NAME \
    PDNS_RUNTIME_GROUP \
    PDNS_GROUP_RECORD_NAME \
    PDNS_REALNAME \
    PDNS_UNIQUE_ID \
    PDNS_PRIMARY_GID


source @SHAREDIR@/pdns-postgresql-helper-constants.sh

if ! dscl . -list "/Users/$PDNS_RUNTIME_USER" >/dev/null 2>&1; then
    >&2 echo "Creating PowerDNS runtime user '$PDNS_RUNTIME_USER'"
    >&2 echo "sudo may prompt you for your password."
    sudo dscl . -create /Users/$PDNS_RUNTIME_USER Password \*
    sudo dscl . -create /Users/$PDNS_RUNTIME_USER UniqueID $PDNS_UNIQUE_ID
    sudo dscl . -create /Users/$PDNS_RUNTIME_USER UserShell /usr/bin/false
    sudo dscl . -change /Users/$PDNS_RUNTIME_USER RecordName $PDNS_RUNTIME_USER "$PDNS_USER_RECORD_NAME"
    sudo dscl . -create /Users/$PDNS_RUNTIME_USER RealName "$PDNS_REALNAME"
    sudo dscl . -create /Users/$PDNS_RUNTIME_USER PrimaryGroupID "$PDNS_PRIMARY_GID"
    sudo dscl . -delete /Users/$PDNS_RUNTIME_USER dsAttrTypeNative:accountPolicyData
    sudo dscl . -delete /Users/$PDNS_RUNTIME_USER AuthenticationAuthority
fi

if ! dscl . -list "/Groups/$PDNS_RUNTIME_GROUP" >/dev/null 2>&1; then
    >&2 echo "Creating PowerDNS runtime group '$PDNS_RUNTIME_USER'"
    >&2 echo "sudo may prompt you for your password."
    sudo dscl . -create /Groups/$PDNS_RUNTIME_GROUP PrimaryGroupID $PDNS_PRIMARY_GID
    sudo dscl . -change /Groups/$PDNS_RUNTIME_GROUP RecordName $PDNS_RUNTIME_GROUP "$PDNS_GROUP_RECORD_NAME"
    sudo dscl . -create /Groups/$PDNS_RUNTIME_GROUP RealName "$PDNS_REALNAME"
fi
