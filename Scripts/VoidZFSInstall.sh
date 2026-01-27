#!/bin/sh -e
# script for installing Void Linux (glibc) on a ZFS root with ZFSBootMenu using hrmpf
# assumes a x86_64 UEFI system

# change these variables to configure the install

# root ROOTdisk of the system
ROOTDISK="/dev/nvme0n1"
# partition used for the bootloader
BOOTDEVICE="${ROOTDISK}p1"
# partition used for the main ZFS pool
ZFSDEVICE="${ROOTDISK}p2"
# name of the main zfs pool
ZPOOLNAME="zpool0"
# name of the primary user
PRIMARYUSER_NAME="skinchanger"

# xbps mirror to use
MIRROR="https://mirrors.servercentral.com/voidlinux/current"
# base package(s) to install
BASEPACKAGE="base-system micro" # death to vi

# hostname of the system
HOSTNAME="foobar"
# glibc locale(s) of the system
LOCALE="en_US.UTF-8 UTF-8 
en_US ISO-8859-1"
# timezone of the system (in /usr/share/zoneinfo)
TIMEZOME="America/Chicago"
# default keymap of the system
KEYMAP="us"

# TODO:
# root password
# primary user name
# primary user password
# setup ZFS swap
# automount ZFS home and bulk dataset

do_warning_start() {
    if [ "$(id -u)" -ne 0 ]; then
	    echo "this script needs to be run as root"
        exit 1
    fi

    echo "WARNING: This script should only be run for OS installs, as it can overwrite all your data."
    echo "Do you wish to continue? [yes/no]"

    local INPUT
    read INPUT

    if [ $INPUT = "yes" ]; then
        return
    else
        echo "Aborting..."
        exit 0
    fi
}

do_rootdisk_prep() {
    zpool labelclear -f "$ROOTDISK"

    wipefs -a "$BOOTDEVICE"
    wipefs -a "$ZFSDEVICE"

    sgdisk --zap-all "$BOOTDEVICE"
    sgdisk --zap-all "$ZFSDEVICE"

    sgdisk -n "1:1m:+512m" -t "1:ef00" "$BOOTDEVICE"
    sgdisk -n "2:0:-10m" -t "2:bf00" "$ZFSDEVICE"
}

do_zfsdevice_prep() {
    zpool create -f -o ashift=12 \
    -O compression=lz4 \
    -O acltype=posixacl \
    -O xattr=sa \
    -O relatime=on \
    -o autotrim=on \
    -o compatibility=openzfs-2.3-linux \
    -m none $ZPOOLNAME "$ZFSDEVICE"

    zfs create -o mountpoint=none                                 $ZPOOLNAME/ROOT
    zfs create -o mountpoint=/                 -o canmount=noauto $ZPOOLNAME/ROOT/void
    zfs create -o mountpoint=none                                 $ZPOOLNAME/HOME
    zfs create -o mountpoint=/home             -o canmount=noauto $ZPOOLNAME/HOME/default
    zfs create -o mountpoint=/home/skinchanger -o canmount=no     $ZPOOLNAME/$PRIMARYUSER_NAME
    zfs create                                 -o canmount=noauto $ZPOOLNAME/$PRIMARYUSER_NAME/Bulk0

    # for ZFSBootMenu
    zpool set bootfs=$ZPOOLNAME/ROOT/void $ZPOOLNAME

    zpool export $ZPOOLNAME
    zpool import -N -R /mnt $ZPOOLNAME
    zfs mount $ZPOOLNAME/ROOT/void
    zfs mount $ZPOOLNAME/HOME/default

    udevadm trigger
}

do_bootstrap() {
    XBPS_ARCH=x86_64 xbps-install -S -R $MIRROR -r /mnt base-system
    cp /etc/hostid /mnt/etc
}

# main()
do_warning_start

zgenhostid
do_rootdisk_prep
do_zfsdevice_prep
do_bootstrap

xchroot /mnt


