#!/bin/bash -e
# script for installing a basic xfce-based gui
# designed to be used with VoidZFSInstall.sh

# gui packages
GUIPACKAGE="xorg-minimal xorg-fonts xorg-video-drivers xorg-input-drivers xfce4 lightdm lightdm-gtk-greeter"

sudo bash -c "
xbps-install -Sy $GUIPACKAGE
touch /etc/sv/lightdm/down
ln -s /etc/sv/{dbus,elogind,lightdm} /var/service/"

mkdir -p $HOME/.config/
echo "\
XDG_DESKTOP_DIR=$HOME/Data/Desktop
XDG_DOWNLOAD_DIR=$HOME/Bulk0/Downloads
XDG_TEMPLATES_DIR=$HOME/Data/Templates
XDG_PUBLICSHARE_DIR=$HOME/Data/Public
XDG_DOCUMENTS_DIR=$HOME/Data/Documents
XDG_MUSIC_DIR=$HOME/Data/Music
XDG_PICTURES_DIR=$HOME/Data/Pictures
XDG_VIDEOS_DIR=$HOME/Data/Videos" \
> $HOME/.config/user-dirs.dirs

echo "Verify that LightDM after rebooting works with 'sv once lightdm', then enable it with 'rm /etc/sv/lightdm/down'"
