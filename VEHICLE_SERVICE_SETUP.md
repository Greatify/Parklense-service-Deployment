# Vehicle Service Deployment Setup

This document outlines the setup and configuration of the Vehicle Management Service deployment within the Parklense platform.

## Overview

The Vehicle Management Service has been integrated into the existing deployment infrastructure alongside the Authentication Service. Both services now share the same Kubernetes cluster and deployment workflows.

## What Has Been Added

### 1. Kubernetes Manifests

#### Base Configuration (`k8s/base/`)
- **Deployment**: `vehicle-backend-deployment.yaml`
  - 2 replicas for high availability
  - Resource limits: 512Mi memory, 500m CPU
  - Health checks and readiness probes
  - Volume mounts for media and static files

- **Service**: `vehicle-backend-service.yaml`
  - ClusterIP service exposing port 80
  - Load balancer integration

- **Ingress**: `vehicle-ingress.yaml`
  - ALB ingress controller configuration
  - SSL/TLS termination
  - Domain routing for vehicle service

- **Secrets**: `parklense-vehicle-secrets.yaml`
  - Database URL, Redis URL, and secret key
  - Base64 encoded placeholder values

- **Autoscaling**: `vehicle-backend-autoscaler.yaml`
  - HPA with CPU and memory targets
  - Scale range: 2-10 replicas

### 2. Environment-Specific Configurations

#### Development (`k8s/overlays/dev/`)
- **Storage**: Added PVCs and PVs for vehicle service
  - `vehicle-media-pvc`: 20Gi for media files
  - `vehicle-static-pvc`: 10Gi for static files
- **Domain**: `vehicle.parklensedev.com`

#### Staging (`k8s/overlays/staging/`)
- **Storage**: Added PVCs and PVs for vehicle service
  - `vehicle-media-pvc`: 50Gi for media files
  - `vehicle-static-pvc`: 20Gi for static files
- **Domain**: `vehicle.parklensedev.com`
- **Patches**: Environment-specific configurations
  - Resource allocation
  - Service account configuration
  - SSL certificate configuration

### 3. Updated Deployment Workflows

#### Development Deployment (`.github/workflows/cd-dev.yaml`)
- Added `vehicle_image` input parameter
- Conditional vehicle service deployment
- Updated image tag updates for both services

#### Staging Deployment (`.github/workflows/cd-staging.yaml`)
- Added `vehicle_image` input parameter
- Conditional vehicle service deployment
- Enhanced health checks for both services

### 4. Vehicle Service CI/CD Integration

#### Build and Deploy Workflow (`Parklense-vehicle-managment-service/.github/workflows/build-deploy.yaml`)
- Updated to trigger deployment in the unified deployment repository
- Sends both auth and vehicle image URLs
- Maintains separate image tagging for vehicle service

## Configuration Details

### Environment Variables
```yaml
# Vehicle Service Environment Variables
DJANGO_SETTINGS_MODULE: config.settings.production
DATABASE_URL: postgresql://vehicle_user:vehicle_password@vehicle_db:5432/vehicle_database
REDIS_URL: redis://redis-service:6379/0
SECRET_KEY: vehicle_secret_key_for_production_environment
ALLOWED_HOSTS: vehicle.parklensedev.com,*.vehicle.parklensedev.com
CORS_ALLOWED_ORIGINS: https://vehicle.parklensedev.com,https://*.vehicle.parklensedev.com
```

### Resource Allocation
| Environment | CPU Request | CPU Limit | Memory Request | Memory Limit |
|-------------|-------------|-----------|----------------|--------------|
| Development | 250m        | 500m      | 256Mi          | 512Mi        |
| Staging     | 500m        | 1         | 1Gi            | 2Gi          |
| Production  | 1           | 2         | 2Gi            | 4Gi          |

### Storage Configuration
| Environment | Media Storage | Static Storage |
|-------------|---------------|----------------|
| Development | 20Gi          | 10Gi           |
| Staging     | 50Gi          | 20Gi           |
| Production  | 100Gi         | 50Gi           |

## Deployment Process

### 1. Vehicle Service Build
```bash
# In vehicle service repository
git push origin main
# Triggers build-deploy.yaml workflow
```

### 2. Unified Deployment
```bash
# Vehicle service workflow triggers deployment repository
# Updates both auth and vehicle service images
# Deploys to selected environment
```

### 3. Health Checks
- **Auth Service**: `https://auth.parklensedev.com/api/health/`
- **Vehicle Service**: `https://vehicle.parklensedev.com/api/health/`

## Setup Instructions

### 1. Initial Setup
```bash
# Run the setup script
./scripts/setup-vehicle-service.sh

# Follow the interactive prompts to:
# - Create ECR repository
# - Create EBS volumes
# - Create SSL certificates
# - Create secrets
# - Deploy the service
```

### 2. Manual Configuration Updates

#### Update ECR Repository URL
```yaml
# In vehicle-backend-deployment.yaml
image: YOUR_ACCOUNT_ID.dkr.ecr.YOUR_REGION.amazonaws.com/parklense-vehicle-managment-service:latest
```

#### Update SSL Certificate ARN
```yaml
# In vehicle-ingress.yaml
alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:REGION:ACCOUNT:certificate/CERTIFICATE_ID
```

#### Update EBS Volume IDs
```yaml
# In overlays/{env}/storage/pv.yaml
awsElasticBlockStore:
  volumeID: vol-xxxxxxxxxxxxxxxxx  # Replace with actual volume ID
```

### 3. Secrets Management
```bash
# Create secrets in AWS Secrets Manager
aws secretsmanager create-secret \
  --name "parklense-vehicle-dev-secrets" \
  --description "Vehicle service secrets for development" \
  --secret-string '{
    "database-url": "postgresql://user:pass@host:5432/db",
    "redis-url": "redis://redis:6379/0",
    "secret-key": "your-secret-key"
  }'
```

## Monitoring and Troubleshooting

### Health Checks
```bash
# Check vehicle service health
curl -f https://vehicle.parklensedev.com/api/health/

# Check Kubernetes resources
kubectl get pods -n dev-parklense-auth -l app=parklense-vehicle-backend
kubectl get services -n dev-parklense-auth -l app=parklense-vehicle-backend
kubectl get ingress -n dev-parklense-auth
```

### Logs
```bash
# View vehicle service logs
kubectl logs -f deployment/parklense-vehicle-backend -n dev-parklense-auth

# View ingress controller logs
kubectl logs -f deployment/aws-load-balancer-controller -n kube-system
```

### Common Issues

1. **Image Pull Errors**
   - Verify ECR repository exists and is accessible
   - Check image tags and ECR credentials

2. **Database Connection Issues**
   - Verify RDS endpoint and security groups
   - Check database credentials in secrets

3. **Storage Issues**
   - Verify EBS volumes exist and are attached
   - Check volume IDs in PV configurations

4. **Ingress Issues**
   - Verify ALB controller is installed
   - Check SSL certificate validation
   - Verify DNS records point to ALB

## Rollback Procedure

```bash
# Rollback vehicle service deployment
kubectl rollout undo deployment/parklense-vehicle-backend -n dev-parklense-auth

# Check rollout status
kubectl rollout status deployment/parklense-vehicle-backend -n dev-parklense-auth

# View rollout history
kubectl rollout history deployment/parklense-vehicle-backend -n dev-parklense-auth
```

## Next Steps

1. **Update CI/CD Pipeline**: Ensure vehicle service repository triggers the correct deployment workflow
2. **Configure Monitoring**: Set up alerts and dashboards for vehicle service
3. **Security Review**: Review and update security configurations
4. **Performance Testing**: Conduct load testing on the vehicle service
5. **Documentation**: Update API documentation and deployment guides

## Support

For issues or questions regarding the vehicle service deployment:
- Check GitHub Actions logs for deployment issues
- Review Kubernetes events: `kubectl get events -n <namespace>`
- Contact the DevOps team via Slack
- Refer to the main README.md for general deployment information 