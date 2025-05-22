#!/bin/bash

# CONFIGURATION
REGION="<REGION>"  # e.g., eu-west-1
AWS_ACCOUNT_ID="<AWS_ACC_I>D"  # e.g., 123456789012
CONTAINER_NAME_PREFIX="<CONTAINER_NAME_PREFIX>" # e.g., haloelasticendpoints
IMAGE="$AWS_ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$CONTAINER_NAME_PREFIX:latest"
NGINX_CONFIG="/etc/nginx/sites-available/<CONFIG>" # Update if your config is elsewhere
BLUE_PORT=5000
GREEN_PORT=5002

echo ""
# Verify the Nginx configuration file exists
if [ ! -f "$NGINX_CONFIG" ]; then
    echo "Error: Nginx configuration file not found: $NGINX_CONFIG"
    exit 1
else
    echo "Nginx configuration file is OK: $NGINX_CONFIG"
fi

# Authenticate Docker to AWS ECR
echo ""
echo "Authenticating to AWS ECR..."
aws ecr get-login-password --region $REGION | \
  docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com
if [ $? -ne 0 ]; then
    echo "ECR authentication failed!"
    exit 1
fi

# Find out which color is live
if grep -qE "^\s*server\s+127\.0\.0\.1:$BLUE_PORT;" "$NGINX_CONFIG"; then
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
echo ""
echo "Currently live: $LIVE_COLOR ($LIVE_PORT)"
echo "Will deploy new: $NEW_COLOR ($NEW_PORT)"

# Pull latest image
docker pull $IMAGE

# Replace previous $NEW_COLOR container if it exists
echo ""
echo "Stopping and removing any existing $NEW_COLOR container to prepare for fresh deployment..."
docker stop $CONTAINER_NAME_PREFIX-$NEW_COLOR 2>/dev/null
docker rm $CONTAINER_NAME_PREFIX-$NEW_COLOR 2>/dev/null


# Run the new container on the correct port
docker run -d --name $CONTAINER_NAME_PREFIX-$NEW_COLOR -p $NEW_PORT:5000 $IMAGE

# Wait a bit (or you can add a health check here)
echo ""
echo "Waiting 10 seconds for the new container to start..."
sleep 10
# Wait for the new container to pass the health check
echo ""
echo "Waiting for the new container to pass the health check..."



# Update nginx config to switch upstream to the new container
if [ "$NEW_COLOR" = "blue" ]; then
    # Comment out Green and uncomment Blue
    sudo sed -i "s/^\s*server\s*127\.0\.0\.1:$GREEN_PORT;/    # server 127.0.0.1:$GREEN_PORT;/" "$NGINX_CONFIG"
    sudo sed -i "s/^\s*#\s*server\s*127\.0\.0\.1:$BLUE_PORT;/    server 127.0.0.1:$BLUE_PORT;/" "$NGINX_CONFIG"
else
    # Comment out Blue and uncomment Green
    sudo sed -i "s/^\s*server\s*127\.0\.0\.1:$BLUE_PORT;/    # server 127.0.0.1:$BLUE_PORT;/" "$NGINX_CONFIG"
    sudo sed -i "s/^\s*#\s*server\s*127\.0\.0\.1:$GREEN_PORT;/    server 127.0.0.1:$GREEN_PORT;/" "$NGINX_CONFIG"
fi

# Test the updated Nginx configuration
echo ""
echo "Testing Nginx configuration..."
sudo nginx -t
if [ $? -ne 0 ]; then
    echo "Nginx configuration test failed!"
    exit 1
fi

echo ""
echo "Reloading nginx..."
sudo systemctl reload nginx
echo ""
echo "Deployment complete! Now serving: $NEW_COLOR"

echo ""
echo "If the deployment fails, you can rollback to the previous version by:"
echo ""
echo "To rollback manually:"
echo "1. Edit $NGINX_CONFIG"
echo "2. Uncomment:     server 127.0.0.1:$LIVE_PORT;"
echo "3. Comment out:   server 127.0.0.1:$NEW_PORT;"
echo "4. Run:           sudo systemctl reload nginx"