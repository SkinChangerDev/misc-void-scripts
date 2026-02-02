#!/bin/bash -e
# script for installing a basic xfce-based gui
# designed to be used with VoidZFSInstall.sh

# util packages
UTILPACKAGE="xdg-user-dirs"
# gui packages
GUIPACKAGE="xorg-minimal xorg-video-drivers xorg-input-drivers xfce4 lightdm lightdm-gtk-greeter"

if [ "$(id -u)" -ne 0 ]; then
    echo "this script needs to be run as root"
    exit 1
fi

xbps-install -Sy $UTILPACKAGE
echo "\
# Default settings for user directories
#
# The values are relative pathnames from the home directory and
# will be translated on a per-path-element basis into the users locale
DESKTOP=Data/Desktop
DOWNLOAD=Bulk0/Downloads
TEMPLATES=Data/Templates
PUBLICSHARE=Data/Public
DOCUMENTS=Data/Documents
MUSIC=Data/Music
PICTURES=Data/Pictures
VIDEOS=Data/Videos" \
> $XDG_CONFIG_DIRS/user-dirs.defaults
xdg-user-dirs-update

xbps-install -Sy $GUIPACKAGE

touch /etc/sv/lightdm/down
ln -s /etc/sv/lightdm /var/service/

echo "Verify that LightDM works with 'sv once lightdm', then enable it with 'rm /etc/sv/lightdm/down'"
