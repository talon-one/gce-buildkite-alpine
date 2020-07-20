build:
	docker build . -t qemu-alpine
	docker run --rm --volume $(shell pwd):/build:Z qemu-alpine /build/docker-entrypoint.sh
