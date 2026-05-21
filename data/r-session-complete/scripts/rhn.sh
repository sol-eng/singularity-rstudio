#!/bin/bash
subscription-manager register --username XXX --password XXX


dnf config-manager --set-disabled "*ubi*"

subscription-manager repos \
    --enable=rhel-$1-for-x86_64-baseos-rpms \
    --enable=rhel-$1-for-x86_64-appstream-rpms
