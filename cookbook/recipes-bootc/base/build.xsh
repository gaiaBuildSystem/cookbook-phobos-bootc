#!/usr/bin/env xonsh

# Copyright (c) 2025 MicroHobby
# SPDX-License-Identifier: MIT

# use the xonsh environment to update the OS environment
$UPDATE_OS_ENVIRON = True
# always return if a cmd fails
$RAISE_SUBPROC_ERROR = True
$XONSH_SHOW_TRACEBACK = True


import os
import sys
import json
import os.path
import subprocess
from datetime import datetime
from torizon_templates_utils.colors import print,BgColor,Color
from torizon_templates_utils.errors import Error_Out,Error


print(
    "building phobos bootc base image ...",
    color=Color.WHITE,
    bg_color=BgColor.GREEN
)

# get the common variables
_ARCH = os.environ.get('ARCH')
_MACHINE = os.environ.get('MACHINE')
_MAX_IMG_SIZE = os.environ.get('MAX_IMG_SIZE')
_BUILD_PATH = os.environ.get('BUILD_PATH')
_DISTRO_MAJOR = os.environ.get('DISTRO_MAJOR')
_DISTRO_MINOR = os.environ.get('DISTRO_MINOR')
_DISTRO_PATCH = os.environ.get('DISTRO_PATCH')
_USER_PASSWD = os.environ.get('USER_PASSWD')

# read the meta data
meta = json.loads(os.environ.get('META', '{}'))

# get the actual script path, not the process.cwd
_path = os.path.dirname(os.path.abspath(__file__))

_IMAGE_MNT_BOOT = f"{_BUILD_PATH}/tmp/{_MACHINE}/mnt/boot"
_IMAGE_MNT_ROOT = f"{_BUILD_PATH}/tmp/{_MACHINE}/mnt/root"
_BUILD_ROOT = f"{_BUILD_PATH}/tmp/{_MACHINE}"
_DEPLOY_PATH = f"{_BUILD_ROOT}/deploy"
os.environ['IMAGE_MNT_BOOT'] = _IMAGE_MNT_BOOT
os.environ['IMAGE_MNT_ROOT'] = _IMAGE_MNT_ROOT
os.environ['BUILD_ROOT'] = _BUILD_ROOT
os.environ['DEPLOY_PATH'] = _DEPLOY_PATH
$BUILD_ROOT = _BUILD_ROOT

# first we need to create the build context
_IMAGE_CONTEXT = f"{_BUILD_PATH}/tmp/{_MACHINE}/bootc-context"
mkdir -p @(f"{_IMAGE_CONTEXT}")

# copy the kernel and initramfs to the build context
cp -r @(f"{_DEPLOY_PATH}/vmlinux") @(f"{_IMAGE_CONTEXT}/")
cp -r @(f"{_DEPLOY_PATH}/initramfs.cpio.gz") @(f"{_IMAGE_CONTEXT}/")

# we need to also copy the modules
cp -r @(f"{_IMAGE_MNT_ROOT}/lib/modules") @(f"{_IMAGE_CONTEXT}/")

# copy the Containerfile to the build context
cp -r @(f"{_path}/Containerfile") @(f"{_IMAGE_CONTEXT}/")

# copy also the assets
cp -r @(f"{_path}/files") @(f"{_IMAGE_CONTEXT}/")

# just move the initramfs to the /usr/lib/modules/ like ostree would like
_kernel_versions = os.listdir(f"{_IMAGE_MNT_ROOT}/usr/lib/modules")

# Assume there is only one directory
if len(_kernel_versions) != 1:
    raise Exception(
        "Expected exactly one kernel version directory in /usr/lib/modules"
    )

cp -a @(f"{_IMAGE_MNT_BOOT}/initramfs.cpio.gz") \
@(f"{_IMAGE_CONTEXT}/modules/{_kernel_versions[0]}/initramfs.img")

# build the image
cd @(f"{_IMAGE_CONTEXT}")

print(
    "fixups done, starting to build the phobos bootc base image ...",
    color=Color.WHITE,
    bg_color=BgColor.BLUE
)

sudo podman \
    build \
    --cap-add=SYS_ADMIN \
    --security-opt=seccomp=unconfined \
    -f ./Containerfile \
    -t localhost/phobos-bootc-base:latest .

_DIGEST=$(sudo podman inspect phobos-bootc-base:latest --format '{{index .Digest}}')

cd -

print(
    "building phobos bootc base image, ok",
    color=Color.WHITE,
    bg_color=BgColor.GREEN
)

print(
    "installing to disk the phobos bootc base image ...",
    color=Color.WHITE,
    bg_color=BgColor.BLUE
)

# clean the rootfs first (must be truly empty for bootc install),
# but keep the mountpoint directory itself
sudo umount @(f"{_IMAGE_MNT_ROOT}/dev/pts")
sudo umount @(f"{_IMAGE_MNT_ROOT}/dev")
sudo umount @(f"{_IMAGE_MNT_ROOT}/proc")
sudo umount @(f"{_IMAGE_MNT_ROOT}/sys")

sudo bash -c @(f"find {_IMAGE_MNT_ROOT} -mindepth 1 -maxdepth 1 -exec sudo rm -rf {{}} +")

# install the container now
sudo podman \
    run \
    --rm \
    --privileged \
    --pid=host \
    -it \
    -v /etc/containers:/etc/containers:Z \
    -v /var/lib/containers:/var/lib/containers:Z \
    -v /var/tmp:/var/tmp:Z \
    -v /dev:/dev \
    -v @(f"{_IMAGE_MNT_ROOT}:{_IMAGE_MNT_ROOT}") \
    -e RUST_LOG=debug \
    -v @(f"{_DEPLOY_PATH}:/data") \
    --security-opt label=type:unconfined_t \
    phobos-bootc-base:latest \
        bootc \
        install \
        to-filesystem \
        --skip-bootloader \
        --u-boot \
        @(f"{_IMAGE_MNT_ROOT}")

# fixups

# 0. remount writable because bootc install it as read-only
sudo mount -o remount,rw @(f"{_IMAGE_MNT_ROOT}")

# 1. the /boot/uEnv.txt symlink
sudo ln -s loader/uEnv.txt @(f"{_IMAGE_MNT_ROOT}/boot/uEnv.txt")

print(
    "installing phobos bootc base image to filesystem, ok",
    color=Color.WHITE,
    bg_color=BgColor.GREEN
)
