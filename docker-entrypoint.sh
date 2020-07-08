#!/bin/sh
set -e
cd /build/

MAJOR_VERSION="${MAJOR_VERSION:-3.8}"
MINOR_VERSION="${MINOR_VERSION:-0}"
ISO_FILENAME="alpine-virt-$MAJOR_VERSION.$MINOR_VERSION-x86_64.iso"
CHECKSUM_FILENAME="$ISO_FILENAME.sha512"
URL="http://dl-cdn.alpinelinux.org/alpine/v$MAJOR_VERSION/releases/x86_64"

if [ ! -e $ISO_FILENAME ]; then
    wget $URL/$ISO_FILENAME
fi

if [ ! -e "${CHECKSUM_FILENAME}" ]; then
    wget $URL/$CHECKSUM_FILENAME
    sha512sum --strict -c $CHECKSUM_FILENAME
fi

./create-vm.exp
