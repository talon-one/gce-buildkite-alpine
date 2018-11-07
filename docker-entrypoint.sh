#!/bin/sh
set -e
apk update
apk add expect cdrkit p7zip tar
cd /build/
./create-vm.exp
