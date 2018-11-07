#!/bin/sh
apk update
apk add curl bash

SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"
$SCRIPTPATH/install2.sh
if [ $? -ne 0 ]; then
    printf "\e[1m\e[5m\e[7mInstallation failed\e[0m\n"
else
    printf "\e[7mInstallation succeeded\e[0m\n"
fi