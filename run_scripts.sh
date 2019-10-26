#!/bin/sh
#ARCH="i386"
#PLUG="firstrib00-32.plug"
ARCH="$1"
PLUG="$2"
./build_firstrib_rootfs_103.sh void rolling $ARCH $PLUG
./build_weedog_initramfs05_s207.sh void
