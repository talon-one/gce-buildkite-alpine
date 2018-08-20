#!/bin/bash

set -e


apk update
apk add dialog curl

items=$(dialog --checklist "Choose which features you want to enable" 0 0 0 \
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

IFS=" "

function install_load_virtio_modules {
    cat << 'EOF' > /etc/modules-load.d/virtio
virtio
virtio_pci
virtio_scsi
virtio_net
EOF
}

function configure_net_online {
    cat << 'EOF' > /etc/conf.d/net-online
interfaces="eth0"
include_ping_test="no"
timeout="0"
EOF
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
    cat <<'EOF' > /etc/init.d/google-instance-setup
#!/sbin/openrc-run
depend() {
    after net network-online logger
    before sshd
    provide google-instance-setup
}

start() {
    /usr/bin/google_instance_setup
}
EOF
    chmod 0700 /etc/init.d/google-instance-setup
    rc-update add google-instance-setup default
    
    cat <<'EOF' > /etc/init.d/google-network-daemon
#!/sbin/openrc-run
command="/usr/bin/google_network_daemon"
command_args=""
pidfile="/run/${RC_SVCNAME}.pid"
command_background=true

depend() {
    after net network-online logger google-instance-setup
    provide google-network-daemon
}
EOF
    chmod 0700 /etc/init.d/google-network-daemon
    rc-update add google-network-daemon default

    cat <<'EOF' > /etc/init.d/google-accounts-daemon
#!/sbin/openrc-run
command="/usr/bin/google_accounts_daemon"
command_args=""
pidfile="/run/${RC_SVCNAME}.pid"
command_background=true

depend() {
    after net network-online logger google-instance-setup google-network-daemon
    provide google-accounts-daemon
}
EOF
    chmod 0700 /etc/init.d/google-accounts-daemon
    rc-update add google-accounts-daemon default

    cat <<'EOF' > /etc/init.d/google-clock-skew-daemon
#!/sbin/openrc-run
command="/usr/bin/google_clock_skew_daemon"
command_args=""
pidfile="/run/${RC_SVCNAME}.pid"
command_background=true

depend() {
    after net network-online logger google-instance-setup google-network-daemon
    provide google-clock-skew-daemon
}
EOF
    chmod 0700 /etc/init.d/google-clock-skew-daemon
    rc-update add google-clock-skew-daemon default

    cat <<'EOF' > /etc/init.d/google-startup-scripts
#!/sbin/openrc-run
depend() {
    after net network-online logger google-instance-setup google-network-daemon
    provide google-startup-scripts
}

start() {
    /usr/bin/google_metadata_script_runner --script-type startup
}
EOF
    chmod 0700 /etc/init.d/google-startup-scripts
    rc-update add google-startup-scripts default

    cat <<'EOF' > /etc/init.d/google-shutdown-scripts
#!/sbin/openrc-run
depend() {
    after net network-online logger google-instance-setup google-network-daemon
    provide google-shutdown-scripts
}

start() {
    /usr/bin/google_metadata_script_runner --script-type shutdown
}
EOF
    chmod 0700 /etc/init.d/google-shutdown-scripts
    rc-update add google-shutdown-scripts shutdown

    configure_net_online
    rc-update add net-online default
}

function install_docker {
    apk add docker shadow sudo
    rc-update add docker default
    rc-service docker start

    case "${items[@]}" in *BuildKite*)
        # if buildkite enabled, run docker containers as buildkite user
        mkdir /etc/docker 2>&1 || true
        cat <<'EOF' > /etc/docker/daemon.json
{
    "userns-remap": "buildkite"
}
EOF
        cat <<'EOF' > /etc/subuid
buildkite:100000:65536
EOF
        cat <<'EOF' > /etc/subgid
buildkite:100000:65536
EOF
    ;;
    esac
}

function install_docker_compose {
    apk add python py-pip
    pip install docker-compose
}

function install_buildkite {
    apk add shadow
    # cleanup old runs
    rm -rf /etc/buildkite-agent 2>&1 || true
    rm -rf /tmp/buildkite 2>&1 || true

    # create needed directories
    mkdir /etc/buildkite-agent 2>&1 || true
    mkdir /tmp/buildkite 2>&1 || true
    pushd /tmp/buildkite
    # download and install
    wget https://github.com/buildkite/agent/releases/download/v3.4.0/buildkite-agent-linux-amd64-3.4.0.tar.gz
    tar -xzf buildkite-agent-linux-amd64-3.4.0.tar.gz
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

    case "${items[@]}" in *Docker*)
        # add user to docker group
        usermod --groups docker --append buildkite
    ;;
    esac

    cat <<'EOF' > /etc/init.d/buildkite-agent
#!/sbin/openrc-run
command="/usr/sbin/buildkite-agent"
command_args="start"
pidfile="/run/${RC_SVCNAME}.pid"
command_background=true
command_user=buildkite
depend() {
    after net network-online logger
    provide buildkite-agent
}
EOF
    sed -i "s/%hostname-%n/$(hostname)-%n/g" /etc/buildkite-agent/buildkite-agent.cfg
    chmod 0700 /etc/init.d/buildkite-agent
    rc-update add buildkite-agent default
    configure_net_online
    rc-update add net-online default

    case "${items[@]}" in *LinuxGuest*)
        # if google is enabled
        # use the config as template
        mv /etc/buildkite-agent/buildkite-agent.cfg /etc/buildkite-agent/buildkite-agent.cfg.template
        # get the token for buildkite from the metadata
        cat <<'EOF' > /etc/init.d/buildkite-agent-settings
#!/sbin/openrc-run
depend() {
    after net network-online logger
    before buildkite-agent
    provide buildkite-agent-settings
}

start() {
    cp /etc/buildkite-agent/buildkite-agent.cfg.template /etc/buildkite-agent/buildkite-agent.cfg

    # fetch token
    token=$(curl --fail --silent "http://metadata.google.internal/computeMetadata/v1/instance/attributes/buildkite-token" -H "Metadata-Flavor: Google")
    status=$?
    if [ $status -ne 0 ]; then
        echo "Unable to get buildkite-token"
        exit $status
    fi
    echo token="$token" >> /etc/buildkite-agent/buildkite-agent.cfg

    # fetch priority
    priority=$(curl --fail --silent "http://metadata.google.internal/computeMetadata/v1/instance/attributes/buildkite-priority" -H "Metadata-Flavor: Google")
    if [ $? -eq 0 ]; then
        echo priority=$priority >> /etc/buildkite-agent/buildkite-agent.cfg
    fi

    # fetch tags
    tags=$(curl --fail --silent "http://metadata.google.internal/computeMetadata/v1/instance/attributes/buildkite-tags" -H "Metadata-Flavor: Google")
    if [ $? -eq 0 ]; then
        echo tags="$tags" >> /etc/buildkite-agent/buildkite-agent.cfg
    fi

    # fetch sshkey
    key=$(curl --fail --silent "http://metadata.google.internal/computeMetadata/v1/instance/attributes/buildkite-sshkey" -H "Metadata-Flavor: Google")
    status=$?
    if [ $status -eq 0 ]; then
        mkdir /home/buildkite/.ssh 2>&1 || true
        echo $key | base64 --decode > /home/buildkite/.ssh/identity
        cat <<'END' > /home/buildkite/.ssh/config
    Host *
        IdentityFile /home/buildkite/.ssh/identity
END
        chown -hR buildkite:buildkite /home/buildkite/.ssh
        chmod -R 0700 /home/buildkite/.ssh
    fi
}
EOF
    chmod 0700 /etc/init.d/buildkite-agent-settings
    rc-update add buildkite-agent-settings default
    ;;
    esac
}



for task in $items
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
for task in $items
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
