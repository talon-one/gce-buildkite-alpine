#!/bin/bash

set -e


if [ -z "$INSTALL_ITEMS" ]; then
    INSTALL_ITEMS=$(dialog --checklist "Choose which features you want to enable" 0 0 0 \
        "VirtioModules" "enable additional virtualization modules" "on" \
        "LinuxGuest" "install google linux guest environment " "on" \
        "Docker" "install Docker" "off" \
        "DockerCompose" "install DockerCompose" "off" \
        "BuildKite" "install BuildKite-Agent (needs Docker and DockerCompose)" "off" \
    3>&1 1>&2 2>&3)
    status=$?
    if [ $status -ne 0 ]; then
        exit $status
    fi
fi

IFS=" "

function install_load_virtio_modules {
    cp ./etc/modules-load.d/virtio /etc/modules-load.d/virtio
}

function configure_net_online {
    cp ./etc/conf.d/net-online /etc/conf.d/net-online
}

function install_google_services {
    # set timezone to UTC
    ln -sf /etc/zoneinfo/UTC /etc/localtime
    # install dependencies
    apk add git sudo shadow dhclient coreutils python py-setuptools ethtool iproute2
    # cleanup old runs
    rm -rf /tmp/compute-image-packages 2>&1 || true
    # clone the services
    git clone --branch "20180611" https://github.com/GoogleCloudPlatform/compute-image-packages.git /tmp/compute-image-packages
    pushd /tmp/compute-image-packages
    ./setup.py install
    popd

    # autostart services
    cp ./etc/init.d/google-instance-setup /etc/init.d/google-instance-setup
    chmod 0700 /etc/init.d/google-instance-setup
    rc-update add google-instance-setup default
    
    cp ./etc/init.d/google-network-daemon /etc/init.d/google-network-daemon
    chmod 0700 /etc/init.d/google-network-daemon
    rc-update add google-network-daemon default

    cp ./etc/init.d/google-accounts-daemon /etc/init.d/google-accounts-daemon
    chmod 0700 /etc/init.d/google-accounts-daemon
    rc-update add google-accounts-daemon default

    cp ./etc/init.d/google-clock-skew-daemon /etc/init.d/google-clock-skew-daemon
    chmod 0700 /etc/init.d/google-clock-skew-daemon
    rc-update add google-clock-skew-daemon default

    cp ./etc/init.d/google-startup-scripts /etc/init.d/google-startup-scripts
    chmod 0700 /etc/init.d/google-startup-scripts
    rc-update add google-startup-scripts default

    cp ./etc/init.d/google-shutdown-scripts /etc/init.d/google-shutdown-scripts
    chmod 0700 /etc/init.d/google-shutdown-scripts
    rc-update add google-shutdown-scripts shutdown

    configure_net_online
    rc-update add net-online default
}

function install_docker {
    apk add docker shadow sudo
    rc-update add docker default
    rc-service docker start

    case "${INSTALL_ITEMS[@]}" in *BuildKite*)
        # if buildkite enabled, run docker containers as buildkite user
        mkdir /etc/docker 2>&1 || true
        cp ./etc/docker/daemon.json /etc/docker/daemon.json
        cp ./etc/subuid /etc/subuid
        cp ./etc/subgid /etc/subgid
    ;;
    esac


    # install garbage collection cronjobs
    cp ./etc/docker/docker-gc-filter /etc/docker/docker-gc-filter
    cp ./etc/periodic/hourly/docker-gc.sh /etc/periodic/hourly/docker-gc.sh
    cp ./etc/periodic/hourly/docker-low-disk-gc.sh /etc/periodic/hourly/docker-low-disk-gc.sh
    cp ./usr/sbin/check-disk-space.sh /usr/sbin/check-disk-space.sh
    chmod 0700 /etc/periodic/hourly/docker-gc.sh
    chmod 0700 /etc/periodic/hourly/docker-low-disk-gc.sh
    chmod 0700 /usr/sbin/check-disk-space.sh
}

function install_docker_compose {
    apk add python py-pip
    pip install docker-compose
}

function install_buildkite {

    echo BUILDKITE_AGENTS=$BUILDKITE_AGENTS

    if [ -z "$BUILDKITE_AGENTS" ]; then
        BUILDKITE_AGENTS=$(dialog --inputbox "Number of BuildKite agents" 0 0 1 3>&1 1>&2 2>&3)
        status=$?
        if [ $status -ne 0 ]; then
            exit $status
        fi
    fi

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
    mv buildkite-agent.cfg /etc/buildkite-agent/
    mv buildkite-agent /usr/sbin/buildkite-agent
    popd
    # setup permissions
    chmod -R 0755 /etc/buildkite-agent
    chmod 0755 /usr/sbin/buildkite-agent

    # add a group
    groupadd --gid 100000 buildkite
    # add user
    useradd --create-home --shell /sbin/nologin --uid 100000 --gid 100000 buildkite

    case "${INSTALL_ITEMS[@]}" in *Docker*)
        # add user to docker group
        usermod --groups docker --append buildkite
    ;;
    esac

    for ((i=1; i<=$BUILDKITE_AGENTS; i++)); do
        cp ./etc/init.d/buildkite-agent /etc/init.d/buildkite-agent-$i
        chmod 0700 /etc/init.d/buildkite-agent-$i
        rc-update add buildkite-agent-$i default
    done
    sed -i "s/%hostname-%n/$(hostname)-%n/g" /etc/buildkite-agent/buildkite-agent.cfg
    configure_net_online
    rc-update add net-online default

    case "${INSTALL_ITEMS[@]}" in *LinuxGuest*)
        # if google is enabled

        # use the config as template
        mv /etc/buildkite-agent/buildkite-agent.cfg /etc/buildkite-agent/buildkite-agent.cfg.template
        cp ./etc/init.d/buildkite-agent-settings /etc/init.d/buildkite-agent-settings
        chmod 0700 /etc/init.d/buildkite-agent-settings
        rc-update add buildkite-agent-settings default

        cp ./etc/init.d/docker-gc-settings /etc/init.d/docker-gc-settings
        chmod 0700 /etc/init.d/docker-gc-settings
        rc-update add docker-gc-settings default

    ;;
    esac
}



for task in $INSTALL_ITEMS
do
case "$task" in
    VirtioModules)
        install_load_virtio_modules
        ;;
    LinuxGuest)
        install_google_services
        ;;
    Docker)
        install_docker
        ;;
    DockerCompose)
        install_docker_compose
        ;;
    BuildKite)
        install_buildkite
        ;;
esac
done



echo "================================================================================"
echo "Everything done, Summary:"
for task in $INSTALL_ITEMS
do
case "$task" in
    VirtioModules)
        echo "VirtioModules added"
        ;;
    LinuxGuest)
        echo "Google Linux Guest Environment installed"
        ;;
    Docker)
        echo "Docker installed"
        ;;
    DockerCompose)
        echo "Docker compose installed"
        ;;
    BuildKite)
        echo "Buildkite installed"
        echo "Update /etc/buildkite-agent/buildkite-agent.cfg accordingly!"
        ;;
esac
done
IFS=$OIFS
