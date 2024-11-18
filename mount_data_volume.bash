#!/bin/bash

###########################################################
#  This script checks than an AWS EC2 ephemeral
#  disk is mounted on the system. If it's not,
#  it checks that a disk is available, formats
#  it if neccesary and mounts it in the specified
#  path.
#
#  Author: Victor Medina (victor.medina@treelogic.com)
#  Date: 2023/06/30
###########################################################

eph_disk_path=/temp_data
eph_disk_name=nvme1n1

root_disk_path=/
root_disk_name=nvme0n1p1

eph_disk_mounted=false

# Define text colors
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

warning_message()
{
        printf "\n${RED}WARNING:${NC}\n"
        printf "${BLUE}Disk /dev/$eph_disk_name ($eph_disk_path) will be ERASED after every restart/reboot\n"
        printf "of this EC2 instance, so please make sure to only use it for temporary storage.\n"
        printf "YOU WILL LOSE ALL THE INFORMATION UPON RESTART!!${NC}\n\n"
}

echo 
echo "Checking status of ephemeral disk /dev/$eph_disk_name..."

# Check if the disk is mounted
# on the right path
if sudo lsblk -f | grep $eph_disk_path &> /dev/null; then eph_disk_mounted=true; else eph_disk_mounted=false; fi

# Check if the disk is formatted
if sudo file -s /dev/$eph_disk_name | grep filesystem &> /dev/null; then eph_disk_formatted=true; else eph_disk_formatted=false; fi

# Check the filesystem of the disk
if [ "$eph_disk_formatted" = true ] && [ "$eph_disk_mounted" = true ]
then
        # If the disk is formatted and mounted, 
        # we don't need to do anyhing else.

        printf "Ephemeral disk /dev/$eph_disk_name already has a file system and it's mounted on $eph_disk_path.\n\n"
        warning_message
        
        exit

fi

if [ "$eph_disk_mounted" = false ]
then
        if [ "$eph_disk_formatted" = false ]
        then
                # Get the file system of the root disk
                # to format the ephemeral with the same
                # file system

                echo "Ephemeral disk /dev/$eph_disk_name does not have a file system."

                root_disk_info_str=$(sudo lsblk -f | grep ' /$')
                # Split string into array by spaces
                IFS=' ' read -r -a root_disk_info <<< $root_disk_info_str
                root_disk_fs=${root_disk_info[1]}

                # Format disk with the same file system as root
                echo "Creating file system for ephemeral disk /dev/$eph_disk_name as $root_disk_fs"
                sudo mkfs -t $root_disk_fs /dev/$eph_disk_name
        fi

        echo "Ephemeral disk /dev/$eph_disk_name is not mounted."
        
        # Check if the ephemeral disk path
        # already exists, and create it if
        # if doesn't.
        if [ ! -d $eph_disk_path ];
        then        
                echo "Creating mounting point on $eph_disk_path for ephemeral disk /dev/$eph_disk_name"

                # Create path
                sudo mkdir $eph_disk_path
                
                # Change permissions
                sudo chmod 775 $eph_disk_path

                # Change owner to current user
                sudo chown ubuntu:ubuntu $eph_disk_path
        fi

        # Mount the disk in the path
        echo "Mounting ephemeral disk /dev/$eph_disk_name on $eph_disk_path"
        sudo mount /dev/$eph_disk_name $eph_disk_path
        
        warning_message
fi

        

