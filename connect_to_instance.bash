#!/bin/bash

print_help (){
    echo ""
    echo "Connect to an instance in AWS Elastic Cloud Computing (EC2)."
    echo "If the instance is stopped, it will be started, and the script"
    echo "will wait for the instance to be running before connecting."
    echo ""
    echo "Format:"
    echo "$0 [ -h | -i [instance_id] -k [keyfile_path] -d [docker_image] [-e [entrypoint_script_path]]"
    echo ""
    echo "-h print this help information"
    echo ""
    echo "-i (Mandatory) instance id of the EC2 machine that we are connecting to."
    echo "  * [instance_id] Instance id should be in the form \"i-\" followed by 17 alphanumeric characters."
    echo ""
    echo "-k (Mandatory) path for the keyfile that contains the authentification for the AWS EC2 account."
    echo "  * [keyfile_path] the path to the keyfile in our local host computer."
    echo ""
    echo "-d (Mandatory) name of the docker image to be run by the instance."
    echo "  * [docker_image] the name of the docker image to be run, given in the format \"image:tag\". The image must exist in the AWS ECR repository."
    echo ""
    echo "-e (Optional. Default: entrypoint.bash) path for the entrypoint script cfor the remote container. If not provided, by default this program will look for file entrypoint.bash in the current directory."
    echo "  * [entrypoint_script_path] the path to the remote container's entrypoint script."
    echo ""
}

check_jp_installation(){
    if ! jp --version &> /dev/null
    then
        echo "** Installing jp"
        sudo apt update
        sudo apt install -y jp
    fi
}

get_instance_data(){	
	data_json_path=$1

	json_str=$(aws ec2 describe-instances --instance-id $instance_id | jp $data_json_path)
	
	# Remove the enclosing square brackets
	# and double quotes with sed to keep
	# only the actual string.
	retrieved_data=$(echo $json_str | sed -e 's/\[ "//' -e 's/" \]//')
}

get_instance_state (){
	get_instance_data "Reservations[].Instances[].State[].Name"
	instance_state=$retrieved_data
	if [[ "$instance_state" == "" ]]; then
		instance_state='stopped'
	fi
}

get_instance_ip (){
	get_instance_data "Reservations[].Instances[].PublicIpAddress"
	instance_ip=$retrieved_data
}

get_instance_hostname(){
	get_instance_data "Reservations[].Instances[].PublicDnsName"
	instance_hostname=$retrieved_data
}

# By default, use file entrypoint.bash in the current directory.
# If a different path and/or file name is provided, overwrite
# this variable with the provided value.
entrypoint_script_path="entrypoint.bash" 


if [ "$#" -gt 0 ]; then
    
    docker_image="mmsegmentation:latest"

    # The character list indicates accepted parameter options.
    # A colon ":" after a parameter indicates the parameter
    # requires (and must be followed by) a value; no semicolon
    # indicates that no value is required by the parameter.
    while getopts "i:k:d:e:h" opt; do
        case $opt in
            i) instance_id="$OPTARG" ;;
            k) keyfile_path="$OPTARG" ;;
            d) docker_image="$OPTARG" ;;
            e) entrypoint_script_path="$OPTARG" ;;
            h) print_help
            exit 1
            ;;
            \?) echo "Invalid option -$OPTARG" >&2
            print_help
            exit 2
            ;;
        esac

        case $OPTARG in
            -*) echo "Option $opt needs a valid argument"
            exit 3
            ;;
        esac
    done
else
    print_help
    exit 1
fi


if ! [[ -f "$entrypoint_script_path" ]]; then				
	echo "Entry point script $entrypoint_script_path was not found. Please provide a valid file."
	exit 4
fi

check_jp_installation

get_instance_state
get_instance_ip
get_instance_hostname

if [[ "$instance_state" == "stopped" ]]; then

	# Start the EC2 instance
	echo "Starting EC2 instance with ID $instance_id"
	aws ec2 start-instances --instance-ids $instance_id

	# Wait for the instance to finish initializing
	# before we can connect
	echo "Waiting for instance to start..."
	aws ec2 wait instance-running --instance-ids $instance_id

	# Wait for 10 seconds before trying to connect;
	# otherwise the connection may get refused
	sleep 10
	echo "Instance is now running"

fi


# Copy script entrypoint.bash and params file
# to the machine so that the docker image 
# can have access to it.

echo "Copying files to instance..."
scp -i $keyfile_path $entrypoint_script_path ubuntu@$instance_ip:/home/ubuntu/workspace/entrypoint.bash 

ml_container_image=$docker_image
ml_container_params="-e DISPLAY=\$DISPLAY -v /tmp/.X11-unix:/tmp/.X11-unix --gpus=all -v /home/ubuntu/workspace/:/workspace --network=host --ipc=host --cap-add=SYS_PTRACE --privileged --device=/dev/video4:/dev/video4 --entrypoint=/workspace/entrypoint.bash"
ml_container_run_command="./launch_job.sh -i $ml_container_image -a \"$ml_container_params\""


# Run command remotely in the EC2 instance
ssh -i $keyfile_path ubuntu@$instance_ip $ml_container_run_command

