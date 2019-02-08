#!/bin/bash
set -e

SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"


# Tweak open rc
printf "\e[7mTweaking open rc\e[0m\n"
echo "rc_interactive=\"YES\"" >> /etc/rc.conf
echo "rc_shell=\"/bin/sh\"" >> /etc/rc.conf
echo "rc_verbose=yes" >> /etc/rc.conf

# install virtio modules
printf "\e[7mInstalling Virtio Modules\e[0m\n"
cp $SCRIPTPATH/etc/modules-load.d/virtio /etc/modules-load.d/virtio


# configure net-online
printf "\e[7mConfiguring net-online\e[0m\n"
cp $SCRIPTPATH/etc/conf.d/net-online /etc/conf.d/net-online
rc-update add net-online default

# install haveged
printf "\e[7mInstalling haveged\e[0m\n"
apk add haveged
rc-update add haveged boot
rc-service haveged start

# install google services
printf "\e[7mInstalling Google Services\e[0m\n"
# set timezone to UTC
ln -sf /etc/zoneinfo/UTC /etc/localtime
# install dependencies
apk add git sudo shadow dhclient coreutils python py-setuptools ethtool iproute2
# cleanup old runs
rm -rf /tmp/compute-image-packages 2>&1 || true
# clone the services
git clone --branch "20180611" https://github.com/talon-one/compute-image-packages.git /tmp/compute-image-packages
pushd /tmp/compute-image-packages
./setup.py install
popd

# autostart services
cp $SCRIPTPATH/etc/init.d/google-instance-setup /etc/init.d/google-instance-setup
chmod 0700 /etc/init.d/google-instance-setup
rc-update add google-instance-setup default

cp $SCRIPTPATH/etc/init.d/google-network-daemon /etc/init.d/google-network-daemon
chmod 0700 /etc/init.d/google-network-daemon
rc-update add google-network-daemon default

cp $SCRIPTPATH/etc/init.d/google-accounts-daemon /etc/init.d/google-accounts-daemon
chmod 0700 /etc/init.d/google-accounts-daemon
rc-update add google-accounts-daemon default

cp $SCRIPTPATH/etc/init.d/google-clock-skew-daemon /etc/init.d/google-clock-skew-daemon
chmod 0700 /etc/init.d/google-clock-skew-daemon
rc-update add google-clock-skew-daemon default

cp $SCRIPTPATH/etc/init.d/google-startup-scripts /etc/init.d/google-startup-scripts
chmod 0700 /etc/init.d/google-startup-scripts
rc-update add google-startup-scripts default

cp $SCRIPTPATH/etc/init.d/google-shutdown-scripts /etc/init.d/google-shutdown-scripts
chmod 0700 /etc/init.d/google-shutdown-scripts
rc-update add google-shutdown-scripts shutdown


# install docker
printf "\e[7mInstalling Docker\e[0m\n"
apk add docker shadow sudo
rc-update add docker default
rc-service docker start

mkdir /etc/docker 2>&1 || true
cp $SCRIPTPATH/etc/docker/daemon.json /etc/docker/daemon.json
cp $SCRIPTPATH/etc/subuid /etc/subuid
cp $SCRIPTPATH/etc/subgid /etc/subgid


# install garbage collection cronjobs
cp $SCRIPTPATH/etc/periodic/hourly/docker-gc /etc/periodic/hourly/docker-gc
chmod 0700 /etc/periodic/hourly/docker-gc
cp $SCRIPTPATH/usr/sbin/docker-purge /usr/sbin/docker-purge

# install docker-credential-file
cp $SCRIPTPATH/etc/init.d/docker-credential-file /etc/init.d/docker-credential-file
chmod 0700 /etc/init.d/docker-credential-file
rc-update add docker-credential-file default

# install docker compose
printf "\e[7mInstalling Docker Compose\e[0m\n"
apk add python py-pip
pip install docker-compose


# install buildkite
printf "\e[7mInstalling Buildkite\e[0m\n"
apk add shadow
# cleanup old runs
rm -rf /etc/buildkite-agent 2>&1 || true
rm -rf /tmp/buildkite 2>&1 || true

# create needed directories
mkdir /etc/buildkite-agent 2>&1 || true
mkdir /tmp/buildkite 2>&1 || true
pushd /tmp/buildkite
# download and install
wget https://github.com/buildkite/agent/releases/download/v3.5.1/buildkite-agent-linux-amd64-3.5.1.tar.gz
tar -xzf buildkite-agent-linux-amd64-3.5.1.tar.gz
mv buildkite-agent /usr/sbin/buildkite-agent
popd
# setup permissions
chmod -R 0755 /etc/buildkite-agent
chmod 0755 /usr/sbin/buildkite-agent

# add a group
groupadd --gid 100000 buildkite
sleep 1

# add user
useradd --create-home --shell /sbin/nologin --uid 100000 --gid 100000 buildkite
sleep 1

# add user to docker group
usermod --groups docker --append buildkite
sleep 1

cp $SCRIPTPATH/etc/init.d/buildkite-agent /etc/init.d/buildkite-agent
chmod 0700 /etc/init.d/buildkite-agent
rc-update add buildkite-agent default

mkdir --mode 0755 /home/buildkite/builds
mkdir --mode 0755 /home/buildkite/plugins
mkdir --mode 0755 /home/buildkite/hooks
chown -hR buildkite:buildkite /home/buildkite


# update /etc/profile
echo "export PS1='\u@\h:\`pwd\`\$ '" >> /etc/profile

cp $SCRIPTPATH/usr/sbin/iamroot /usr/sbin/iamroot
chmod 0755 /usr/sbin/iamroot
cp $SCRIPTPATH/usr/sbin/iambuildkite /usr/sbin/iambuildkite
chmod 0755 /usr/sbin/iambuildkite

# update /etc/motd

printf "\e[1m\e[7m" > /etc/motd
printf "                                           \n" >> /etc/motd
printf "  Welcome to buildkite-agent               \n" >> /etc/motd
printf "                                           \n" >> /etc/motd
printf "  Commands                                 \n" >> /etc/motd
printf "    iamroot         | switch to root       \n" >> /etc/motd
printf "    iambuildkite    | switch to buildkite  \n" >> /etc/motd
printf "                                           \n" >> /etc/motd
printf "\e[0m\n" >> /etc/motd
