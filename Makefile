build:
	docker run --rm --volume $(shell pwd):/build justincormack/alpine-qemu /build/docker-entrypoint.sh