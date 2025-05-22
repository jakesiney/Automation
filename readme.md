# Docker Blue-Green Deployment Script for AWS ECR

This script automates the process of deploying a new version of a Docker container using the **blue-green deployment strategy**. It updates the Nginx configuration to switch traffic between the blue and green environments and ensures zero downtime during deployment.

---

## Features

- **Blue-Green Deployment**: Switches traffic between two environments (blue and green) to ensure seamless updates.
- **Docker Integration**: Pulls the latest Docker image and runs the container on the appropriate port.
- **Nginx Configuration Update**: Updates the Nginx `upstream` block to route traffic to the active environment.
- **Rollback Instructions**: Provides manual rollback steps in case of deployment failure.

---

## Prerequisites

1. **AWS CLI**: Ensure the AWS CLI is installed and configured with the necessary permissions to access ECR.
2. **Docker**: Docker must be installed and running on the server.
3. **Nginx**: Nginx must be installed and configured with an `upstream` block for blue-green environments.
4. **Nginx Configuration File**: The Nginx configuration file must include an `upstream` block with the following structure:

### Example Nginx Configuration

```nginx
upstream integrator {
    # Blue environment running on port 5000
    # Uncomment this to make Blue active
    server 127.0.0.1:5000;

    # Green environment running on port 5002
    # Uncomment this to make Green active
    # server 127.0.0.1:5002;
}

server {
    listen 80;
    server_name example.com;

    location / {
        proxy_pass http://integrator;
    }
}