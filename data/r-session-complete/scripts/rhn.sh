#!/bin/bash
subscription-manager register --username "$RH_USER_NAME" --password "$RH_USER_PASS"


dnf config-manager --set-disabled "*ubi*"

subscription-manager repos \
    --enable=rhel-$1-for-x86_64-baseos-rpms \
    --enable=rhel-$1-for-x86_64-appstream-rpms
