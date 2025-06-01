#!/bin/bash

CloverStatus=/home/ims/1Clover-tools/status.txt

echo Clover Boot Manager - $(date) > $CloverStatus
echo BIOS Version : $(sudo dmidecode -s bios-version) >> $CloverStatus
cat /etc/os-release | grep 'PRETTY_NAME\|VERSION_ID\|BUILD_ID' >> $CloverStatus
uname -a >> $CloverStatus

# check for dump files
dumpfiles=$(ls -l /sys/firmware/efi/efivars/dump-type* 2> /dev/null | wc -l)

if [ $dumpfiles -gt 0 ]
then
	echo dump files exists. performing cleanup. >> $CloverStatus
	sudo rm -f /sys/firmware/efi/efivars/dump-type*
else
	echo no dump files. no action needed. >> $CloverStatus
fi

# Sanity Check - are the needed EFI entries available?
efibootmgr | grep -i Clover &> /dev/null
if [ $? -eq 0 ]
then
	echo Clover EFI entry exists! No need to re-add Clover. >> $CloverStatus
else
	echo Clover EFI entry is not found. Need to re-ad Clover. >> $CloverStatus
	efibootmgr -c -d /dev/nvme1n1 -p 1 -L "Clover - GUI Boot Manager" -l "\EFI\clover\cloverx64.efi" &> /dev/null
fi

# efibootmgr | grep -i Steam &> /dev/null
# if [ $? -eq 0 ]
# then
# 	echo SteamOS EFI entry exists! No need to re-add SteamOS. >> $CloverStatus
# else
# 	echo SteamOS EFI entry is not found. Need to re-add SteamOS. >> $CloverStatus
# 	efibootmgr -c -d /dev/nvme1n1 -p 1 -L "SteamOS" -l "\EFI\steamos\steamcl.efi" &> /dev/null
# fi

# disable the Windows EFI entry!
test -f /boot/efi/efi/Microsoft/Boot/bootmgfw.efi && echo Windows EFI exists! Moving it to /boot/efi/efi/Microsoft >> $CloverStatus && sudo cp /boot/efi/efi/Microsoft/Boot/bootmgfw.efi /boot/efi/efi/Microsoft/Boot/bootmgfw.efi.orig && sudo mv /boot/efi/efi/Microsoft/Boot/bootmgfw.efi /boot/efi/efi/Microsoft &>> $CloverStatus

# re-arrange the boot order and make Clover the priority!
Clover=$(efibootmgr | grep -i Clover | colrm 9 | colrm 1 4)
#SteamOS=$(efibootmgr | grep -i SteamOS | colrm 9 | colrm 1 4)
efibootmgr -o $Clover &> /dev/null

echo "*** Current state of EFI entries ****" >> $CloverStatus
efibootmgr | grep -iv 'Boot2\|PXE' >> $CloverStatus
echo "*** Current state of EFI partition ****" >> $CloverStatus
df -h | grep -i 'Filesystem\|boot/efi' >> $CloverStatus
chown ims:ims $CloverStatus
