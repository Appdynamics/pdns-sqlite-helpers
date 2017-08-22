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

declare PDNS_RUNTIME_USER \
    PDNS_USER_ALIAS \
    PDNS_RUNTIME_GROUP \
    PDNS_GROUP_ALIAS \
    PDNS_REALNAME \
    PDNS_UNIQUE_ID \
    PDNS_PRIMARY_GID


source @SHAREDIR@/pdns-sqlite-helper-constants.sh

if ! dscl . -list "/Users/$PDNS_RUNTIME_USER" >/dev/null 2>&1; then
    >&2 echo "Creating PowerDNS runtime user '$PDNS_RUNTIME_USER'"
    >&2 echo "sudo may prompt you for your password."
    sudo dscl . -create /Users/$PDNS_RUNTIME_USER Password \*
    sudo dscl . -create /Users/$PDNS_RUNTIME_USER UniqueID $PDNS_UNIQUE_ID
    sudo dscl . -create /Users/$PDNS_RUNTIME_USER UserShell /usr/bin/false
    sudo dscl . -merge /Users/$PDNS_RUNTIME_USER RecordName $PDNS_RUNTIME_USER "$PDNS_USER_ALIAS"
    sudo dscl . -create /Users/$PDNS_RUNTIME_USER RealName "$PDNS_REALNAME"
    sudo dscl . -create /Users/$PDNS_RUNTIME_USER PrimaryGroupID "$PDNS_PRIMARY_GID"
    sudo dscl . -delete /Users/$PDNS_RUNTIME_USER dsAttrTypeNative:accountPolicyData
    sudo dscl . -delete /Users/$PDNS_RUNTIME_USER AuthenticationAuthority
fi

if ! dscl . -list "/Groups/$PDNS_RUNTIME_GROUP" >/dev/null 2>&1; then
    >&2 echo "Creating PowerDNS runtime group '$PDNS_RUNTIME_USER'"
    >&2 echo "sudo may prompt you for your password."
    sudo dscl . -create /Groups/$PDNS_RUNTIME_GROUP PrimaryGroupID $PDNS_PRIMARY_GID
    sudo dscl . -merge /Groups/$PDNS_RUNTIME_GROUP RecordName $PDNS_RUNTIME_GROUP "$PDNS_GROUP_ALIAS"
    sudo dscl . -create /Groups/$PDNS_RUNTIME_GROUP RealName "$PDNS_REALNAME"
fi
