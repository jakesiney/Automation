!/bin/bash

# NO PORT MAPPING
# It pulls the latest image from AWS ECR, stops and removes the existing container if it exists,
# and starts a new container with the latest image.
# It does not map any ports, as it is assumed that the container will be run in a network
# It is assumed that the Docker daemon is running and that the user has permission to run Docker commands.
# It is also assumed that the AWS CLI is installed and configured with the necessary permissions
# to access the ECR repository.
# This script is intended to be run in a CI/CD pipeline or as part of a deployment process.


# Variables (update these if needed)
REGION="<REGION>"  # e.g., us-west-1
ACCOUNT="<ACCOUNT_ID>"  # e.g., 497204980916
REPO="<REPO_NAME>" 
IMAGE="$ACCOUNT.dkr.ecr.$REGION.amazonaws.com/$REPO:latest"
CONTAINER_NAME="<CONTAINER_NAME>"

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
docker run -d --name $CONTAINER_NAME $IMAGE cron -f # Replace with your command
# If you need to run a specific command, replace 'cron -f' with your command
# For example, if you want to run a web server, you might use:
# docker run -d --name $CONTAINER_NAME -p 80:80 $IMAGE
# If you need to map ports, add the -p option with the desired port mapping
# For example, to map port 80 on the host to port 80 in the container:

echo "Deployment complete!"