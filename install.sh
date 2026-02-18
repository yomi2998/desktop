#!/usr/bin/env bash
set -e

check_debian_13() {
        if [ -f /etc/os-release ]; then
                . /etc/os-release
                if [ "$ID" != "debian" ] || [ "$VERSION_ID" != "13" ]; then
                        echo "This script is intended for Debian 13. Please run it on a compatible system."
                        exit 1
                fi
        else
                echo "Cannot determine the operating system. Please run this script on Debian 13."
                exit 1
        fi
}

install_packages() {
        sudo apt update
        sudo apt install $1
}

enable_non_free_repos() {
        echo "Enabling non-free repositories..."
        for f in /etc/apt/sources.list; do
                [ -f "$f" ] || continue
                # skip if any active deb line already contains non-free
                if grep -qE '^\s*deb .*non-free' "$f"; then
                        continue
                fi
                # only modify active deb lines and don't duplicate components
                sed -i '/^[[:space:]]*deb /{ /non-free/! s/\<main\>/& non-free/ }' "$f"
        done
}

enable_non_free_firmware_repos() {
        echo "Enabling non-free-firmware repositories..."
        for f in /etc/apt/sources.list; do
                [ -f "$f" ] || continue
                if grep -qE '^\s*deb .*non-free-firmware' "$f"; then
                        continue
                fi
                sed -i '/^[[:space:]]*deb /{ /non-free-firmware/! s/\<main\>/& non-free-firmware/ }' "$f"
        done
}

enable_contrib_repos() {
        echo "Enabling contrib repositories..."
        for f in /etc/apt/sources.list; do
                [ -f "$f" ] || continue
                if grep -qE '^\s*deb .*contrib' "$f"; then
                        continue
                fi
                sed -i '/^[[:space:]]*deb /{ /contrib/! s/\<main\>/& contrib/ }' "$f"
        done
}

enable_sudo() {
        echo "Enabling sudo for the current user..."
        apt update
        apt install -y sudo
        echo -n "Enter your username: "
        read USERNAME
        sudo usermod $USERNAME -aG sudo
}

install_discord() {
        su $USERNAME -c "cd ~ &&
        mkdir -p temp &&
        cd temp &&
        git clone https://github.com/yomi2998/discord-binary-installer.git &&
        cd discord-binary-installer &&
        ./install.sh &&
        cd ../.. &&
        rm -rf temp &&
        /home/$USERNAME/.local/bin/disco &&
        /home/$USERNAME/.local/bin/disco --canary"
}

install_flatpak_apps() {
        flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
        su $USERNAME -c "flatpak install app/com.obsproject.Studio/x86_64/stable runtime/com.obsproject.Studio.Plugin.GStreamerVaapi/x86_64/stable && flatpak install -y app/md.obsidian.Obsidian/x86_64/stable"
}

copy_keychron_rules() {
        cp files/99-keychron.rules /etc/udev/rules.d/
        sudo udevadm control --reload-rules && sudo udevadm trigger
}

copy_config_files() {
        su $USERNAME -c "mkdir -p /home/$USERNAME/.config && cp -r files/.config/* /home/$USERNAME/.config/"
}

post_install() {
        systemctl enable gdm3
        systemctl set-default graphical.target
        mv /etc/network/interfaces /etc/network/interfaces.bak
        systemctl enable NetworkManager
}

main() {
        check_debian_13

        enable_sudo
        enable_non_free_repos
        enable_non_free_firmware_repos
        enable_contrib_repos

        install_packages "ffmpeg libavcodec-extra gstreamer1.0-plugins-bad gstreamer1.0-plugins-ugly gstreamer1.0-libav"

        GENERAL_PACKAGES="
                sway sway-notification-center swaylock swayimg
                gnome-keyring gdm3
                wofi grim slurp waybar mpv thunar clipman pulseaudio-utils brightnessctl
                nwg-look nwg-displays 
                xwayland xwaylandvideobridge
                xdg-desktop-portal-gtk xdg-desktop-portal-wlr wlr-randr wl-clipboard
                chromium firefox-esr
                fcitx5 fcitx5-chinese-addons
                fonts-noto* fonts-font-awesome
                build-essential cmake make gdb lldb clang clang-format llvm nlohmann-json3-dev
                nano git curl wget ntfs-3g aria2 flatpak autotiling network-manager network-manager-applet seahorse
        "
        install_packages "$GENERAL_PACKAGES"
        install_flatpak_apps

        copy_keychron_rules
        copy_config_files
        install_discord
        post_install
}

main