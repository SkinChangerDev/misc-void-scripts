#!/bin/bash -e
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
# size of the swap volume
SWAPSIZE="4G"

# xbps mirror to use
MIRROR="https://mirrors.servercentral.com/voidlinux/current"
# base package(s) to install
BASEPACKAGE="base-system socklog-void cronie ntp xtools htop micro" # death to vi
# bootloader packages to install
BOOTPACKAGE="zfs zfsbootmenu systemd-boot-efistub efibootmgr"

# hostname of the system
INSTALL_HOSTNAME="foobar"
# glibc locale(s) of the system
INSTALL_LOCALE="en_US.UTF-8 UTF-8 
en_US ISO-8859-1"
# timezone of the system (in /usr/share/zoneinfo)
INSTALL_TIMEZOME="America/Chicago"
# default keymap of the system
INSTALL_KEYMAP="us"

# name of the primary user
PRIMARYUSER_NAME="alice"
# groups of the primary user
PRIMARYUSER_GROUPS="wheel,audio,video,floppy,cdrom,optical,kvm,users,xbuilder"

bootstrap_package() {
    XBPS_ARCH=x86_64 xbps-install -Sy -R $MIRROR -r /mnt $@
}

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

    wipefs -a "$ROOTDISK"
    sgdisk --zap-all "$ROOTDISK"

    sgdisk -n "1:1m:+512m" -t "1:ef00" "$ROOTDISK"
    sgdisk -n "2:0:-10m" -t "2:bf00" "$ROOTDISK"
}

do_bootdevice_prep() {
    mkfs.vfat -F32 "$BOOTDEVICE"

    mkdir -p /mnt/boot/efi
    mount $BOOTDEVICE /mnt/boot/efi
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

    # create unencrypted datasets
    zfs create  -o mountpoint=none                                         $ZPOOLNAME/ROOT
    zfs create  -o mountpoint=/                       -o canmount=noauto   $ZPOOLNAME/ROOT/void
    zfs create  -o mountpoint=none                                         $ZPOOLNAME/HOME
    zfs create  -o mountpoint=/home                   -o canmount=noauto   $ZPOOLNAME/HOME/default
    zfs create  -o mountpoint=/home/$PRIMARYUSER_NAME -o canmount=off      $ZPOOLNAME/$PRIMARYUSER_NAME
    zfs create                                                             $ZPOOLNAME/$PRIMARYUSER_NAME/Bulk0
    zfs create                                                             $ZPOOLNAME/$PRIMARYUSER_NAME/Data

    # create encrypted dataset
    echo "Creating encrypted user dataset, set a passphrase:"
    zfs create  -o encryption=on -o keylocation=prompt \
                -o keyformat=passphrase -o canmount=noauto                 $ZPOOLNAME/$PRIMARYUSER_NAME/Encrypted

    # create swap volume
    zfs create -V $SWAPSIZE -o compression=off -o dedup=off -o sync=always $ZPOOLNAME/swap
    mkswap /dev/zvol/$ZPOOLNAME/swap

    # set properties for ZFSBootMenu
    zpool set bootfs=$ZPOOLNAME/ROOT/void $ZPOOLNAME
    zfs set org.zfsbootmenu:commandline="quiet" $ZPOOLNAME/ROOT
    mkdir -p /mnt/etc/zfs
    zpool set cachefile=/mnt/etc/zfs/zpool.cache $ZPOOLNAME

    # mount the new datasets
    zpool export $ZPOOLNAME
    zpool import -N -R /mnt $ZPOOLNAME
    zfs mount $ZPOOLNAME/ROOT/void
    zfs mount $ZPOOLNAME/HOME/default

    # update device symlinks
    udevadm trigger
}

do_bootstrap() {
    # install packages
    bootstrap_package $BASEPACKAGE $BOOTPACKAGE

    # set hostid
    cp /etc/hostid /mnt/etc

    # set hostname
    echo "$INSTALL_HOSTNAME" > /mnt/etc/hostname
    echo "\
# IPv4 hosts
127.0.0.1	localhost
127.0.1.1	${INSTALL_HOSTNAME}

# IPv6 hosts
::1	localhost ip6-localhost ip6-loopback
ff02::1	ip6-allnodes
ff02::2	ip6-allrouters"\
    > /mnt/etc/hosts

    # keymap and hardware clock
    echo "$(cat /mnt/etc/rc.conf)
KEYMAP=\"${INSTALL_KEYMAP}\"
HARDWARECLOCK=\"UTC\""\
    > /mnt/etc/rc.conf

    # set timezone
    ln -sf /mnt/usr/share/zoneinfo/$INSTALL_TIMEZOME /mnt/etc/localtime

    # set glibc locale
    echo "$(cat /mnt/etc/default/libc-locales)
${INSTALL_LOCALE}"\
    > /mnt/etc/default/libc-locales

    # generate fstab
    blkid > /tmp/blkid-out
    BOOTUUID=$(grep "$BOOTDEVICE" /tmp/blkid-out | cut -d ' ' -f 2)
    rm /tmp/blkid-out
    echo "\
# See fstab(5).
#
# <file system>	<dir>	<type>	<options>	<dump>	<pass>
tmpfs	/tmp		tmpfs	defaults,nosuid,nodev	0	0
$BOOTUUID	/boot/efi	vfat	defaults	0	0
/dev/zvol/$ZPOOLNAME/swap	none	swap	defaults	0	0"\
    > /mnt/etc/fstab

    # setup rc.local
    echo "$(cat /mnt/etc/rc.local)

# Mount zfs datasets
zfs mount $ZPOOLNAME/HOME/default
zfs mount $ZPOOLNAME/$PRIMARYUSER_NAME/Bulk0
zfs mount $ZPOOLNAME/$PRIMARYUSER_NAME/Data"\
    > /mnt/etc/rc.local

    # configure ZFSBootMenu
    echo "\
Global:
  ManageImages: true
  BootMountPoint: /boot/efi
  DracutConfDir: /etc/zfsbootmenu/dracut.conf.d
  PreHooksDir: /etc/zfsbootmenu/generate-zbm.pre.d
  PostHooksDir: /etc/zfsbootmenu/generate-zbm.post.d
  InitCPIOConfig: /etc/zfsbootmenu/mkinitcpio.conf
Components:
  ImageDir: /boot/efi/EFI/zbm
  Versions: 3
  Enabled: false
EFI:
  ImageDir: /boot/efi/EFI/zbm
  Versions: false
  Enabled: true
  SplashImage: /etc/zfsbootmenu/splash.bmp
Kernel:
  CommandLine: ro quiet loglevel=0"\
    > /mnt/etc/zfsbootmenu/config.yaml

    # enable services
    ln -s /etc/sv/{dhcpcd,socklog-unix,nanoklogd,cronie,isc-ntpd} /mnt/etc/runit/runsvdir/default/

    # force reconfigure all packages
    xbps-reconfigure -fa -r /mnt
}

do_usersetup() {
    # set root password
    echo "Set root password"
    passwd -R /mnt

    # create primary user
    useradd -G "$PRIMARYUSER_GROUPS" -R /mnt -U "$PRIMARYUSER_NAME"
    echo "Set primary user password"
    passwd -R /mnt "$PRIMARYUSER_NAME"

    # enable sudo for wheel group
    sed -i "s/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/g" /mnt/etc/sudoers
}

# main()
do_warning_start

zgenhostid
do_rootdisk_prep
do_zfsdevice_prep
do_bootdevice_prep

do_bootstrap
do_usersetup

# generate EFI boot images
xchroot /mnt bash -c 'generate-zbm'
efibootmgr -c -d "$ROOTDISK" -p "1" -L "ZFSBootMenu" -l '\EFI\ZBM\VMLINUZ.EFI'
efibootmgr -c -d "$ROOTDISK" -p "1" -L "ZFSBootMenu (Backup)" -l '\EFI\ZBM\VMLINUZ-BACKUP.EFI'

umount -n -R /mnt
zpool export $ZPOOLNAME

echo "All done, ready for first boot!"
