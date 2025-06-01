#!/bin/bash

# define variables here
CLOVER=$(efibootmgr | grep -i Clover | colrm 9 | colrm 1 4)
STEAMOS=$(efibootmgr | grep -i SteamOS | colrm 9 | colrm 1 4)
REFIND=$(efibootmgr | grep -i rEFInd | colrm 9 | colrm 1 4)
CLOVER_VERSION=5161
CLOVER_URL=https://github.com/CloverHackyColor/CloverBootloader/releases/download/$CLOVER_VERSION/Clover-$CLOVER_VERSION-X64.iso.7z
CLOVER_ARCHIVE=$(curl -s -O -L -w "%{filename_effective}" $CLOVER_URL)
CLOVER_BASE=$(basename -s .7z $CLOVER_ARCHIVE)

clear

echo Clover Dual Boot Install Script 


if [ "$(passwd --status $(whoami) | tr -s " " | cut -d " " -f 2)" == "P" ]
then
	read -s -p "Please enter current sudo password: " current_password ; echo
	echo Checking if the sudo password is correct.
	echo -e "$current_password\n" | sudo -S -k ls &> /dev/null

	if [ $? -eq 0 ]
	then
		echo Sudo password is good!
	else
		echo Sudo password is wrong! Re-run the script and make sure to enter the correct sudo password!
		exit
	fi
else
	echo Sudo password is blank! Setup a sudo password first and then re-run script!
	passwd
	exit
fi

# sanity check - is there enough spoace on esp
mkdir ~/temp-ESP
echo -e "$current_password\n" | sudo -S mount /dev/nvme1n1p1 ~/temp-ESP
if [ $? -eq 0 ]
then
	echo ESP has been mounted.
else
	echo Error mounting ESP.
	rmdir ~/temp-ESP
	exit
fi

ESP=$(df /dev/nvme1n1p1 --output=avail | tail -n1)
if [ $ESP -ge 15000 ]
then
	echo ESP partition has $ESP KB free space.
	echo ESP partition has enough free space.
	echo -e "$current_password\n" | sudo -S umount ~/temp-ESP
	rmdir ~/temp-ESP
else
	echo ESP partition has $ESP KB free space.
	echo Not enough space on the ESP partition!
	echo -e "$current_password\n" | sudo -S du -hd2 /esp
	echo -e "$current_password\n" | sudo -S umount ~/temp-ESP
	rmdir ~/temp-ESP
	exit
fi





# obtain Clover ISO
/usr/bin/7z x $CLOVER_ARCHIVE -aoa $CLOVER_BASE &> /dev/null
if [ $? -eq 0 ]
then
	echo Clover has been downloaded from the github repo!
else
	echo Error downloading Clover!
	exit
fi

# mount Clover ISO
mkdir ~/temp-clover &> /dev/null
echo -e "$current_password\n" | sudo -S mount $CLOVER_BASE ~/temp-clover &> /dev/null
if [ $? -eq 0 ]
then
	echo Clover ISO has been mounted!
else
	echo Error mounting ISO!
	echo -e "$current_password\n" | sudo -S umount ~/temp-clover
	rmdir ~/temp-clover
	exit
fi

# copy Clover files to EFI system partition
echo -e "$current_password\n" | sudo -S cp -Rf ~/temp-clover/efi/clover /boot/efi/efi/
echo -e "$current_password\n" | sudo -S cp custom/config.plist /boot/efi/efi/clover/config.plist 
echo -e "$current_password\n" | sudo -S cp -Rf custom/themes/* /boot/efi/efi/clover/themes

# delete temp directories created and delete the Clover ISO
#echo -e "$current_password\n" | sudo -S umount ~/temp-clover
#rmdir ~/temp-clover
#rm Clover-$CLOVER_VERSION-X64.iso*

# remove previous Clover entries before re-creating them
for entry in $CLOVER
do
	echo -e "$current_password\n" | sudo -S efibootmgr -b $entry -B &> /dev/null
done

# install Clover to the EFI system partition
echo -e "$current_password\n" | sudo -S efibootmgr -c -d /dev/nvme1n1 -p 1 -L "Clover - GUI Boot Manager" -l "\EFI\clover\cloverx64.efi" &> /dev/null
echo -e "$current_password\n" | sudo -S mv /boot/efi/efi/boot/bootx64.efi /boot/efi/efi/boot/bootx64.efi.orig 
echo -e "$current_password\n" | sudo -S cp /boot/efi/efi/clover/cloverx64.efi /boot/efi/efi/boot/bootx64.efi

# Backup and disable the Windows EFI entry!
echo -e "$current_password\n" | sudo -S cp /boot/efi/efi/Microsoft/Boot/bootmgfw.efi /boot/efi/efi/Microsoft/Boot/bootmgfw.efi.orig &> /dev/null
echo -e "$current_password\n" | sudo -S mv /boot/efi/efi/Microsoft/Boot/bootmgfw.efi /boot/efi/efi/Microsoft &> /dev/null

# re-arrange the boot order and make Clover the priority!
echo -e "$current_password\n" | sudo -S efibootmgr -n $CLOVER &> /dev/null
#echo -e "$current_password\n" | sudo -S efibootmgr -o $CLOVER &> /dev/null

# Final sanity check
efibootmgr | grep "Clover - GUI" &> /dev/null
if [ $? -eq 0 ]
then
	echo Clover has been successfully installed to the EFI system partition!
else
	echo Whoopsie something went wrong. Clover is not installed.
	exit
fi

# create ~/1Clover-tools and place the scripts in there
mkdir ~/1Clover-tools &> /dev/null
rm -f ~/1Clover-tools/* &> /dev/null
cp custom/Clover-Toolbox.sh ~/1Clover-tools &> /dev/null
echo -e "$current_password\n" | sudo -S cp custom/clover-bootmanager.service custom/clover-bootmanager.sh /etc/systemd/system
cp -R custom/logos ~/1Clover-tools &> /dev/null
cp -R custom/efi ~/1Clover-tools &> /dev/null
#sudo cp ~/1Clover-tools/logos/SteamDeckLogo.png /boot/efi/efi/steamos/steamos.png &> /dev/null

# make the scripts executable
chmod +x ~/1Clover-tools/Clover-Toolbox.sh
echo -e "$current_password\n" | sudo -S chmod +x /etc/systemd/system/clover-bootmanager.sh

# start the clover-bootmanager.service
echo -e "$current_password\n" | sudo -S systemctl daemon-reload
echo -e "$current_password\n" | sudo -S systemctl enable --now clover-bootmanager.service
echo -e "$current_password\n" | sudo -S /etc/systemd/system/clover-bootmanager.sh

# copy dolphin root extension to easily add themes
#mkdir -p ~/.local/share/kservices5/ServiceMenus
#cp custom/open_as_root.desktop ~/.local/share/kservices5/ServiceMenus

# create desktop icon for Clover Toolbox
ln -s ~/1Clover-tools/Clover-Toolbox.sh ~/Desktop/Clover-Toolbox &> /dev/null
echo -e Desktop icon for Clover Toolbox has been created!

echo Clover install completed!
