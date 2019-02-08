FROM alpine:3.9
RUN apk add -U bash curl qemu qemu-img qemu-system-x86_64 expect cdrkit p7zip tar