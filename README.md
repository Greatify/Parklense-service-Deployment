# Parklense Platform Deployment

This repository contains the Kubernetes deployment configurations for the Parklense platform, including both the Authentication Service and Vehicle Management Service.

## Services

### 1. Authentication Service (`parklense-auth-service`)
- **Repository**: [Parklense-auth-service](https://github.com/Greatify/Parklense-auth-service)
- **Purpose**: Handles user authentication, authorization, and user management
- **Components**:
  - Django backend API
  - Celery worker for background tasks
  - Celery beat for scheduled tasks
  - Redis for caching and message broker

### 2. Vehicle Management Service (`parklense-vehicle-managment-service`)
- **Repository**: [Parklense-vehicle-managment-service](https://github.com/Greatify/Parklense-vehicle-managment-service)
- **Purpose**: Manages vehicle data, registration, and vehicle-related operations
- **Components**:
  - Django backend API
  - Media storage for vehicle images
  - Static file serving

## Architecture

### Kubernetes Structure
```
k8s/
├── base/                          # Base configurations shared across environments
│   ├── deployment/               # Deployment manifests
│   │   ├── auth-backend-deployment.yaml
│   │   ├── celery-worker-deployment.yaml
│   │   ├── celery-beat-deployment.yaml
│   │   ├── redis-deployment.yaml
│   │   └── vehicle-backend-deployment.yaml
│   ├── services/                 # Service manifests
│   │   ├── auth-backend-service.yaml
│   │   ├── redis-service.yaml
│   │   └── vehicle-backend-service.yaml
│   ├── ingress/                  # Ingress configurations
│   │   ├── ingress.yaml          # Auth service ingress
│   │   └── vehicle-ingress.yaml  # Vehicle service ingress
│   ├── secrets/                  # Secret configurations
│   │   ├── parklense-auth-secrets.yaml
│   │   └── parklense-vehicle-secrets.yaml
│   └── autoscaling/              # HPA configurations
│       ├── auth-backend-autoscaler.yaml
│       ├── celery-worker-autoscaler.yaml
│       ├── redis-autoscaler.yaml
│       └── vehicle-backend-autoscaler.yaml
└── overlays/                     # Environment-specific configurations
    ├── dev/                      # Development environment
    ├── staging/                  # Staging environment
    └── prod/                     # Production environment
```

### Environment URLs

#### Development
- **Auth Service**: https://auth.parklensedev.com
- **Vehicle Service**: https://vehicle.parklensedev.com

#### Staging
- **Auth Service**: https://auth.parklensedev.com
- **Vehicle Service**: https://vehicle.parklensedev.com

#### Production
- **Auth Service**: https://auth.parklense.com
- **Vehicle Service**: https://vehicle.parklense.com

## Deployment Workflows

### Development Deployment
- **Trigger**: Manual workflow dispatch or push to `dev` branch
- **Workflow**: `.github/workflows/cd-dev.yaml`
- **Inputs**:
  - `image`: Auth service Docker image
  - `vehicle_image`: Vehicle service Docker image (optional)
  - `sha`: Git commit SHA
  - `commit_message`: Commit message

### Staging Deployment
- **Trigger**: Manual workflow dispatch
- **Workflow**: `.github/workflows/cd-staging.yaml`
- **Inputs**: Same as development
- **Additional**: Creates PR for production deployment

### Production Deployment
- **Trigger**: Manual workflow dispatch or merge to main
- **Workflow**: `.github/workflows/cd-prod.yaml`
- **Inputs**: Same as development
- **Additional**: Includes rollback capabilities

## Prerequisites

### AWS Infrastructure
- EKS cluster
- ECR repositories for both services
- RDS PostgreSQL databases
- ElastiCache Redis
- Application Load Balancer
- SSL certificates
- EBS volumes for persistent storage

### Required Secrets
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_REGION`
- `EKS_CLUSTER_NAME`
- `PAT_TOKEN` (GitHub Personal Access Token)
- `DEPLOYMENT_TOKEN`
- `SLACK_WEBHOOK_URL`

## Quick Start

### 1. Deploy to Development
```bash
# Trigger via GitHub Actions UI or API
# Required inputs:
# - image: ECR image URL for auth service
# - vehicle_image: ECR image URL for vehicle service (optional)
# - sha: Git commit SHA
# - commit_message: Commit message
```

### 2. Deploy to Staging
```bash
# Same as development but with staging environment
# Automatically creates production deployment PR
```

### 3. Deploy to Production
```bash
# Requires approval and PR merge
# Includes comprehensive health checks and rollback
```

## Monitoring and Health Checks

### Health Endpoints
- **Auth Service**: `/api/health/`
- **Vehicle Service**: `/api/health/`

### Monitoring
- Kubernetes pod status
- Service availability
- Ingress health
- Application health checks
- Slack notifications for deployment status

## Troubleshooting

### Common Issues

1. **Image Pull Errors**
   - Verify ECR repository exists
   - Check image tags
   - Ensure ECR credentials are configured

2. **Database Connection Issues**
   - Verify RDS endpoint and credentials
   - Check security groups
   - Validate database URL format

3. **Storage Issues**
   - Verify EBS volumes exist
   - Check volume IDs in PV configurations
   - Ensure storage class is available

4. **Ingress Issues**
   - Verify ALB controller is installed
   - Check SSL certificate ARNs
   - Validate host configurations

### Rollback Procedure
```bash
# Rollback to previous deployment
kubectl rollout undo deployment/parklense-auth-backend -n <namespace>
kubectl rollout undo deployment/parklense-vehicle-backend -n <namespace>

# Check rollout status
kubectl rollout status deployment/parklense-auth-backend -n <namespace>
kubectl rollout status deployment/parklense-vehicle-backend -n <namespace>
```

## Contributing

1. Create feature branch from `main`
2. Make changes to Kubernetes configurations
3. Test in development environment
4. Create pull request
5. Get approval and merge

## Support

For deployment issues or questions:
- Check GitHub Actions logs
- Review Kubernetes events: `kubectl get events -n <namespace>`
- Contact DevOps team via Slack 