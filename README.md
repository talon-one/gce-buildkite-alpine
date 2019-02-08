# Buildkite for GCE
This repo contains everything you need use buildkite on GCE.


## Use docker to build the image
1. Make sure you download and place `alpine-virt-3.8.0-x86_64.iso` in this folder
2. Run `docker run --rm --volume $(pwd):/build justincormack/alpine-qemu /build/docker-entrypoint.sh` in this folder
3. Get a cup of coffee
4. disk.raw.tar.gz should be created


## Without docker
1. Make sure you download and place `alpine-virt-3.8.0-x86_64.iso` in this folder
2. Make sure you have installed expect qemu and mkisofs
3. run create-vm.exp
4. Get a cup of coffee
5. disk.raw.tar.gz should be created

Then upload disk.raw.tar.gz to your google bucket (and import it to gce afterwards)


Available google cloud settings:

```
buildkite-token        | token to use for buildkite
buildkite-sshkey       | ssh private key to use (base64 encoded)
buildkite-tags         | tags for the buildkite agents
buildkite-priority     | priority to use (if not specified use current timestamp)
buildkite-agent-count  | agents to use in this image
docker-credential-file | json credential file for docker (base64 encoded)
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
