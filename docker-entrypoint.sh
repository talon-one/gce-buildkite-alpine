#!/bin/sh
set -e
apk update
apk add expect cdrkit p7zip tar
cd /build/
if [ ! -e "alpine-virt-3.8.0-x86_64.iso" ]; then
    wget http://dl-cdn.alpinelinux.org/alpine/v3.8/releases/x86_64/alpine-standard-3.8.1-x86_64.iso
fi
./create-vm.exp
