#! /bin/bash

print_help (){
    echo "Mount an AWS S3 bucket on a local folder."
    echo ""
    echo "Format:"
    echo "$0 [ [[-p (mount_path)] [-b (bucket_name)] [-u]] | [-h] ]"
    echo "-p path to the directory where the bucket is to be mounted"
    echo "-b name of the AWS bucket to mount"
    echo "-u force unmount of the bucket if already mounted"
    echo "-h print this help information"
    echo "Example: $0 -p $HOME/amazon-aws-s3-drive -b april-raw-data-internal"
}


# Set default values for parameters
#mount_path="$HOME/amazon-aws-s3-drive"
#bucket_name="april-raw-data-internal"
force_unmount=false

# If command-line parameters are passed in,
# overwrite their default value with them.
if [ "$#" -gt 0 ]; then
    # The character list indicates accepted parameter options.
    # A semicolon ":" after a parameter indicates the parameter
    # requires (and must be followed by) a value; no semicolon
    # indicates that no value is required by the parameter.
    while getopts ":p:b:uh" opt; do
        case $opt in
            p) mount_path="$OPTARG" ;;
            b) bucket_name="$OPTARG" ;;
            u) force_unmount=true ;;
            h) print_help
            exit 2
            ;;
            \?) echo "Invalid option -$OPTARG" >&2
            print_help
            exit 1
            ;;
        esac

        case $OPTARG in
            -*) echo "Option $opt needs a valid argument"
            exit 1
            ;;
        esac
    done
else
    print_help
    exit 1
fi


# Find if the script was run via 
# "bash [script]" or "source [script]"
# to determine whether to "exit" or "return"
# upon error
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]
then 
    script_sourced=true
else
    script_sourced=false
fi

# Exit script if drive is already mounted
if [[ $(cat /proc/mounts | grep $mount_path) ]]
then
    s3_mount_type=$(cat /proc/mounts | grep -o -P '(?<='$mount_path' ).*(?= r)')
    echo "Directory $mount_path already mounted as type $s3_mount_type."
    # Unmount the directory if "-u" (force unmount) 
    # option is enabled
    if $force_unmount
    then
        echo "Unmounting $mount_path"
        umount $mount_path
    else
	echo "Add option -u to force unmount the directory."
        if $script_sourced
        then
            return
        else
            exit
        fi
    fi
fi

# Check if s3fs is installed
# and install it if it's not
if ! command -v s3fs &> /dev/null
then
    if [[ $EUID -ne 0 ]]; then
        echo "This script must be run as root" 
        exit 1
    fi
    echo "Installing s3fs..."
    apt-get update
    apt-get -y install s3fs
fi

# Check if s3 folder exists
# and create it if it doesn't
if [ ! -d $mount_path ]
then
    echo "Creating mounting directory..."
    mkdir $mount_path
fi

# connect filesystem with remote s3 bucket
echo "Mounting bucket $bucket_name on $mount_path..."

s3fs $bucket_name $mount_path
if [ $? -ne 0 ]; then
    echo "Something went wrong"
else
    echo "Bucket $bucket_name was successfully mounted on $mount_path"
    echo "(Type \"umount $mount_path\" to unmount the bucket)"
fi

