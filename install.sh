#!/usr/bin/env bash

set -e

reset="\033[0m"
cyan="\033[1;36m"
magenta="\033[1;35m"
sep="${cyan}::${reset}"
line="${magenta} ->${reset}"

echo -en "${sep} Console keyboard layout: "
read keyboard

echo -en "${sep} Username: "
read username

echo -e "${sep} Reinstalling archlinux-keyring..."
pacman -Sy archlinux-keyring --noconfirm

echo -e "${sep} Updating the mirror list..."
pacman -S reflector --noconfirm
reflector --latest 5 --sort rate --save /etc/pacman.d/mirrorlist

echo -e "${sep} Installing essential packages..."
pacstrap -K /mnt base base-devel linux linux-firmware \
  efibootmgr grub os-prober ntfs-3g gvfs ntp networkmanager dhcpcd polkit \
  reflector xorg-server xorg-xinit gnome-keyring openssh libsecret git nano \
  alsa-tools alsa-utils pipewire-pulse pipewire-pulse pipewire-jack rtkit at-spi2-core

echo -e "${sep} Generating the fstab file..."
genfstab -U /mnt >> /mnt/etc/fstab

cat << EOF > /mnt/root/install.sh
#!/usr/bin/env bash

set -e

echo -e "${sep} Configuring the system..."
echo -e "${line} Setting the time zone (1/15)"
ln -sf /usr/share/zoneinfo/America/Mexico_City /etc/localtime
hwclock --systohc

echo -e "${line} Configuring the locale (2/15)"
sed -i "s/#en_US.UTF-8/en_US.UTF-8/" /etc/locale.gen
echo LANG=en_US.UTF-8 > /etc/locale.conf
locale-gen

echo -e "${line} Setting the console keyboard layout (3/15)"
echo KEYMAP=$keyboard > /etc/vconsole.conf

echo -e "${line} Assigning the hostname (4/15)"
echo archlinux >> /etc/hostname

echo -e "${line} Creating the root password (5/15)"
passwd

echo -e "${line} Creating the user password (6/15)"
useradd -m -G wheel -s /bin/bash $username
passwd $username

echo -e "${line} Adding the user to the sudoers file (7/15)"
sed -i "s/# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/" /etc/sudoers

echo -e "${line} Enabling Network Manager (8/15)"
systemctl enable NetworkManager.service

echo -e "${line} Updating pacman configuration (9/15)"
sed -i "s/#Color/Color\nILoveCandy/" /etc/pacman.conf

echo -e "${line} Updating PAM configuration (10/15)"
sed -i "6 i auth       optional     pam_gnome_keyring.so" /etc/pam.d/login
echo "session    optional     pam_gnome_keyring.so auto_start" >> /etc/pam.d/login

echo -e "${line} Updating the mirror list (11/15)"
reflector --latest 5 --sort rate --save /etc/pacman.d/mirrorlist

echo -e "${line} Installing an AUR helper (12/15)"
pushd /opt
mkdir -p yay-bin
chown $username yay-bin
sudo -i -u $username bash -c "git clone https://aur.archlinux.org/yay-bin.git /opt/yay-bin"
sudo -i -u $username bash -c "cd /opt/yay-bin; makepkg -si --noconfirm"
popd

echo -e "${line} Installing the GRUB bootloader (13/15)"
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=ArchLinux

echo -e "${line} Enabling os-prober (14/15)"
sed -i "s/#GRUB_DISABLE_OS_PROBER=false/GRUB_DISABLE_OS_PROBER=false/" /etc/default/grub

echo -e "${line} Generating GRUB configuration file (15/15)"
grub-mkconfig -o /boot/grub/grub.cfg
EOF

chmod +x /mnt/root/install.sh

echo -e "${sep} Entering the mounted disk as root..."
arch-chroot /mnt /root/install.sh

echo -e "${sep} Cleaning up..."
rm -rf /mnt/root/install.sh
rm -rf /mnt/opt/yay-bin

echo -e "${sep} Unmounting file systems..."
umount -R /mnt

echo -e "${sep} Installation has finished, you can restart now"
