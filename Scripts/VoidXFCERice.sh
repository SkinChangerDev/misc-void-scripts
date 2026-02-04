#!/bin/bash -e
# script for ricing xfce
# designed to be used with VoidXFCEInstall.sh

# theme and icons
THEMEPACKAGE="Adapta papirus-icon-theme papirus-folders"
# fonts
FONTPACKAGE="noto-fonts-emoji noto-fonts-ttf noto-fonts-ttf-extra noto-fonts-ttf-variable"
# utilities
UTILPACKAGE="xfce4-whiskermenu-plugin xfce4-pulseaudio-plugin xfce4-screenshooter \
qt6ct mugshot menulibre lightdm-gtk-greeter-settings \
gnome-disk-utility qdirstat file-roller seahorse blueman \
xreader system-config-printer simple-scan \
gucharmap qalculate-gtk flatpak xdg-desktop-portal-gtk"

sudo xbps-install -Sy $THEMEPACKAGE $FONTPACKAGE $UTILPACKAGE
