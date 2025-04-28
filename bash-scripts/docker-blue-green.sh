#!/bin/bash

# CONFIGURATION
IMAGE="<aws_account_id>.dkr.ecr.<region>.amazonaws.com/<your-repo>:latest"
REGION="<region>"  # e.g., eu-west-1
AWS_ACCOUNT_ID="<aws_account_id>"  # e.g., 123456789012
NGINX_CONFIG="/etc/nginx/sites-enabled/config.conf" # Update if your config is elsewhere
CONTAINER_NAME_PREFIX="synergy-integrator"
BLUE_PORT=5000
GREEN_PORT=5002

# Authenticate Docker to AWS ECR
echo "Authenticating to AWS ECR..."
aws ecr get-login-password --region $REGION | \
  docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com
if [ $? -ne 0 ]; then
    echo "ECR authentication failed!"
    exit 1
fi

# Find out which color is live
if grep -q "server 127.0.0.1:$BLUE_PORT;" "$NGINX_CONFIG" | grep -v '#' ; then
    LIVE_COLOR="blue"
    LIVE_PORT=$BLUE_PORT
    NEW_COLOR="green"
    NEW_PORT=$GREEN_PORT
else
    LIVE_COLOR="green"
    LIVE_PORT=$GREEN_PORT
    NEW_COLOR="blue"
    NEW_PORT=$BLUE_PORT
fi

echo "Currently live: $LIVE_COLOR ($LIVE_PORT)"
echo "Will deploy new: $NEW_COLOR ($NEW_PORT)"

# Pull latest image
docker pull $IMAGE

# Stop and remove the inactive container if running
docker stop $CONTAINER_NAME_PREFIX-$NEW_COLOR 2>/dev/null
docker rm $CONTAINER_NAME_PREFIX-$NEW_COLOR 2>/dev/null

# Run the new container on the correct port
docker run -d --name $CONTAINER_NAME_PREFIX-$NEW_COLOR -p $NEW_PORT:5000 $IMAGE

# Wait a bit (or you can add a health check here)
echo "Waiting 10 seconds for the new container to start..."
sleep 10

# Update nginx config to switch upstream to the new container
if [ "$NEW_COLOR" = "blue" ]; then
    # Set 5000 active, comment out 5002
    sed -i "s/^\s*server 127\.0\.0\.1:$GREEN_PORT;/    # server 127.0.0.1:$GREEN_PORT;/" "$NGINX_CONFIG"
    sed -i "s/^\s*# server 127\.0\.0\.1:$BLUE_PORT;/    server 127.0.0.1:$BLUE_PORT;/" "$NGINX_CONFIG"
else
    # Set 5002 active, comment out 5000
    sed -i "s/^\s*server 127\.0\.0\.1:$BLUE_PORT;/    # server 127.0.0.1:$BLUE_PORT;/" "$NGINX_CONFIG"
    sed -i "s/^\s*# server 127\.0\.0\.1:$GREEN_PORT;/    server 127.0.0.1:$GREEN_PORT;/" "$NGINX_CONFIG"
fi

echo "Reloading nginx..."
nginx -s reload

# Optionally: stop and remove the old container
docker stop $CONTAINER_NAME_PREFIX-$LIVE_COLOR 2>/dev/null
docker rm $CONTAINER_NAME_PREFIX-$LIVE_COLOR 2>/dev/null

echo "Deployment complete! Now serving: $NEW_COLOR"