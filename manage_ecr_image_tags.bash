#!/bin/bash

print_help (){
    echo ""
    echo "Manage tags (versions) for docker images in the AWS Elastic Container Registry (ECR)"
    echo ""
    echo "Format:"
    echo "$0 [ -h | -l [repository_name] | -d [repository_name] [image_tag] | -a [repository_name] [current tag] [new tag] ]"
    echo ""
    echo "-h print this help information"
    echo ""
    echo "-l List tags for all the images in repository [repository_name]."
    echo "  * [repository_name] is the name of the AWS ECR repository where the image is stored."
    echo ""
    echo "-d Delete a tag. WARNING!: if the image only has one tag, the entire image will be deleted."
    echo "  * [repository_name] is the name of the AWS ECR repository where the image is stored."
    echo "  * [image_tag] is the tag to delete from the image."
    echo ""
    echo "-a Add a tag. The old tags will be kept and the new one will be added to the image."
    echo "  * [repository_name] is the name of the AWS ECR repository where the image is stored."
    echo "  * [current_tag] is one of the tags of the image version we want to modify tags for."
    echo "  * [new_tag] New tag to add to the image (only applies if flag -a is used)."
    echo ""
    echo "Examples: "
    echo "* List all tags for image mmsegmentation:latest --> $0 -l mmsegmentation latest"
    echo "* Add tag 0.2 to image mmsegmentation:latest --> $0 -a mmsegmentation latest 0.2"
    echo "* Delete tag 0.2 from image mmsegmentation:latest --> $0 -d mmsegmentation 0.2"
    echo ""
}

REPOSITORY_NAME=$2
CURR_TAG=$3
NEW_TAG=$4

if [ "$#" -gt 0 ]; then
    if [ "$1" == "-h" ]; then
        print_help
        exit 1
    elif [ "$1" == "-d" ]; then

        if [ "$#" -lt 3 ]; then
            echo "Missing parameters for option \"$1\""
            echo "Format: $0 $1 [repository_name] [image_tag]"
            exit 2
        fi
        
        aws ecr batch-delete-image --repository-name $REPOSITORY_NAME --image-ids imageTag=$CURR_TAG
        echo "New tags:"
        aws ecr list-images --repository-name $REPOSITORY_NAME | jq '.imageIds | map (.imageTag)|sort|.[]' | sort -r

    elif [ "$1" == "-l" ]; then

        if [ "$#" -lt 2 ]; then
            echo "Missing parameters for option \"$1\""
            echo "Format: $0 $1 [repository_name]"
            exit 2
        fi

        aws ecr list-images --repository-name $REPOSITORY_NAME | jq '.imageIds | map (.imageTag)|sort|.[]' | sort -r

    elif [ "$1" == "-a" ]; then

        if [ "$#" -lt 4 ]; then
            echo "Missing parameters for option \"$1\""
            echo "Format: $0 $1 [repository_name] [current tag] [new tag]"
            exit 2
        fi

        echo "Current tag: $CURR_TAG"
        echo "New tag: $NEW_TAG"

        MANIFEST=$(aws ecr batch-get-image --repository-name $REPOSITORY_NAME --image-ids imageTag=$CURR_TAG --output json | jq --raw-output --join-output '.images[0].imageManifest')
        aws ecr put-image --repository-name $REPOSITORY_NAME --image-tag $NEW_TAG --image-manifest "$MANIFEST"
        echo "New tags:"
        aws ecr list-images --repository-name $REPOSITORY_NAME | jq '.imageIds | map (.imageTag)|sort|.[]' | sort -r
    fi
else
    print_help
    exit 1
fi



