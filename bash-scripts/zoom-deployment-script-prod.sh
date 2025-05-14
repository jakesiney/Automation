#!/bin/bash

# Variables (update these if needed)
REGION="us-west-1"
ACCOUNT="497204980916"
REPO="synergyzoomintegrator"
IMAGE="$ACCOUNT.dkr.ecr.$REGION.amazonaws.com/$REPO:latest"
CONTAINER_NAME="synergyzoomintegrator"

# Authenticate to ECR
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ACCOUNT.dkr.ecr.$REGION.amazonaws.com

# Pull the latest image
docker pull $IMAGE

# Stop the existing container if running
if [ "$(docker ps -q -f name=$CONTAINER_NAME)" ]; then
    echo "Stopping running container: $CONTAINER_NAME"
    docker stop $CONTAINER_NAME
fi

# Remove the existing container if present
if [ "$(docker ps -a -q -f name=$CONTAINER_NAME)" ]; then
    echo "Removing existing container: $CONTAINER_NAME"
    docker rm $CONTAINER_NAME
fi

# Start the new container
echo "Starting new container: $CONTAINER_NAME"
docker run -d --rm --name $CONTAINER_NAME -p 8181:8181 $IMAGE 

echo "Deployment complete!" 