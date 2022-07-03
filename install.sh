#!/bin/bash

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

echo -e "${sep} Configuring mirrors..."
pacman -Syy reflector --noconfirm
reflector --sort rate -l 5 --save /etc/pacman.d/mirrorlist

echo -e "${sep} Installing essential packages..."
pacstrap /mnt base base-devel efibootmgr git grub gvfs linux linux-firmware pulseaudio nano networkmanager os-prober

echo -e "${sep} Generating fstab file..."
genfstab -U /mnt >> /mnt/etc/fstab

cat << EOF > /mnt/root/install.sh
#!/bin/bash

set -e

echo -e "${sep} Done, now configuring the system..."
echo -e "${line} Set the time zone. (1/16)"
ln -sf /usr/share/zoneinfo/America/Mexico_City /etc/localtime
hwclock --systohc

echo -e "${line} Set the localization. (2/16)"
sed -i "s/#en_US.UTF-8/en_US.UTF-8/" /etc/locale.gen
echo LANG=en_US.UTF-8 > /etc/locale.conf
locale-gen

echo -e "${line} Set the console keyboard layout. (3/16)"
echo KEYMAP=$keyboard > etc/vconsole.conf

echo -e "${line} Set the hostname. (4/16)"
echo archlinux >> /etc/hostname

echo -e "${line} Insert the root password. (5/16)"
passwd

echo -e "${line} Creating user... (6/16)"
useradd -m -G wheel -s /bin/bash $username

echo -e "${line} Insert the user password. (7/16)"
passwd $username

echo -e "${line} Add user to sudoers file. (8/16)"
sed -i "s/# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/" /etc/sudoers

echo -e "${line} Enable Network Manager. (9/16)"
systemctl enable NetworkManager.service

echo -e "${line} Modify pacman configuration. (10/16)"
sed -i "s/#Color/Color\nILoveCandy/" /etc/pacman.conf

echo -e "${sep} Configuring mirrors... (11/16)"
pacman -S reflector --noconfirm
reflector --sort rate -l 5 --save /etc/pacman.d/mirrorlist

echo -e "${line} Installing the AUR helper... (12/16)"
pushd /opt
mkdir -p yay-bin
chown $username yay-bin
sudo -i -u $username bash -c "git clone https://aur.archlinux.org/yay-bin.git /opt/yay-bin"
sudo -i -u $username bash -c "cd /opt/yay-bin; makepkg -si --noconfirm"
popd

echo -e "${line} Installing Xorg... (13/16)"
pacman -S xorg-server --noconfirm

echo -e "${line} Installing GRUB... (14/16)"
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=ArchLinux

echo -e "${line} Enable os-prober. (15/16)"
sed -i "s/GRUB_DISABLE_OS_PROBER=true/GRUB_DISABLE_OS_PROBER=false/" /etc/default/grub

echo -e "${line} Generate the GRUB configuration file. (16/16)"
grub-mkconfig -o /boot/grub/grub.cfg
EOF

chmod +x /mnt/root/install.sh

echo -e "${sep} Changing system root..."
arch-chroot /mnt /root/install.sh

echo -e "${sep} Cleaning up..."
rm -rf /mnt/root/install.sh
rm -rf /mnt/opt/yay-bin

echo -e "${sep} Umounting the file systems..."
umount -R /mnt

echo -e "${sep} Installation finished."
