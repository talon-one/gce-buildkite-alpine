# Buildkite for GCE
This repo contains everything you need use buildkite on GCE.

1. Download the disk.raw.tar.gz and upload it to a google bucket
2. Create an image
3. Create an instance and specify the `buildkite-token` and `buildkite-sshkey` (base64 encoded, private key) as metadata



# Creating an own image
```
1. Boot alpine-virt-3.8.0-x86_64.iso in Virtualbox
1.1. Make sure to select exactly 20gb fixed storage (.vdi)
2. Login with Username root and no password
3. run setup-alpine
- set timezone to utc
- do not setup a root password
- install on the drive
- make sure to select "sys" when asked how to store data
4. Eject iso
5. Boot from HDD
---
6. in /etc/update-extlinux.conf
6.1 add default_kernel_opts="... cgroup_enable=memory swapaccount=1"
6.2 remove quiet, rhgb and splashimage= from default_kernel_opts
6.3 set timeout to timeout=1
6.1. Run update-extlinux
7. uncomment /community in /etc/apk/repositories
8. install bash (apk add bash) and download and run script.sh (use wget)
9. clear ash history and remove the script.sh (rm -rf ~/.ash_history script.sh)
10. shutdown (halt)
--- 
11. Export the disk to the .raw file format
        VBoxManage clonehd filepath/to/disk.vdi disk.raw --format RAW
    or 
        VBoxManage internalcommands converttoraw filepath/to/disk.vdi  disk.raw
12. Pack it to .tar.gz tar -Sczf disk.raw.tar.gz disk.raw
```

# Changelog
```
1.0 Initial release
1.1 * optional buildkite-sshkey
    * user namespaces for docker
1.2 * Specify the count of buildkite agents using buildkite-agent-count
    * take name from google cloud as buildkite agent name
    * cronjobs to cleanup old docker files
1.3 * fixed cronjobs permissions
    * purge all not just networks and images
```
