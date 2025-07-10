# Parklense Authentication Service - Deployment

This repository contains the Kubernetes deployment configurations and CI/CD pipelines for the Parklense Authentication Service.

## 🏗️ Architecture Overview

The Parklense Authentication Service is deployed on AWS EKS using a microservices architecture:

- **Django Backend**: Main authentication API service
- **Celery Workers**: Background task processing (email, SMS, etc.)
- **Celery Beat**: Scheduled task management
- **Redis**: Cache and message broker
- **PostgreSQL**: Primary database (managed RDS)

## 📁 Repository Structure

```
├── .github/workflows/          # GitHub Actions CI/CD pipelines
│   ├── ci.yaml                # Continuous Integration
│   ├── cd-dev.yaml            # Development deployment
│   ├── cd-staging.yaml        # Staging deployment
│   └── cd-prod.yaml           # Production deployment
├── k8s/                       # Kubernetes configurations
│   ├── base/                  # Base Kustomize configurations
│   │   ├── deployment/        # Deployment manifests
│   │   ├── services/          # Service manifests
│   │   ├── ingress/           # Ingress configurations
│   │   ├── configmap/         # ConfigMaps
│   │   ├── secrets/           # Secret configurations
│   │   └── autoscaling/       # HPA configurations
│   └── overlays/              # Environment-specific overlays
│       ├── dev/               # Development environment
│       ├── staging/           # Staging environment
│       └── prod/              # Production environment
├── scripts/                   # Deployment scripts
│   ├── deploy.sh              # Manual deployment script
│   └── rollback.sh            # Rollback script
└── docs/                      # Documentation
    └── secrets-template.env   # Environment variables template
```

## 🚀 Quick Start

### Prerequisites

1. **AWS CLI** configured with appropriate permissions
2. **kubectl** installed and configured
3. **Docker** for local testing
4. **yq** for YAML processing

### Setup Environment

1. Clone this repository:
```bash
git clone https://github.com/your-org/Parklense-auth-service-Deployment.git
cd Parklense-auth-service-Deployment
```

2. Configure AWS credentials:
```bash
aws configure
```

3. Update kubeconfig for your EKS cluster:
```bash
aws eks update-kubeconfig --name your-cluster-name --region ap-south-1
```

## 🔐 Secrets Management

We use AWS Secrets Manager for secure environment variable management.

### Creating Secrets

1. Use the template in `docs/secrets-template.env`
2. Create secrets in AWS Secrets Manager:

```bash
# Development
aws secretsmanager create-secret \
  --name "parklense-auth-dev-secrets" \
  --description "Development environment secrets" \
  --secret-string file://dev-secrets.env

# Staging
aws secretsmanager create-secret \
  --name "parklense-auth-staging-secrets" \
  --description "Staging environment secrets" \
  --secret-string file://staging-secrets.env

# Production
aws secretsmanager create-secret \
  --name "parklense-auth-prod-secrets" \
  --description "Production environment secrets" \
  --secret-string file://prod-secrets.env
```

### Required IAM Permissions

Ensure your EKS service accounts have permission to access secrets:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ],
      "Resource": [
        "arn:aws:secretsmanager:*:*:secret:parklense-auth-*"
      ]
    }
  ]
}
```

## 🚢 Deployment

### Automated Deployment (Recommended)

Deployments are automatically triggered through GitHub Actions:

1. **Development**: Automatically deployed on push to `main` branch
2. **Staging**: Manual trigger via GitHub Actions UI
3. **Production**: Manual trigger with approval requirements

### Manual Deployment

Use the provided deployment script:

```bash
# Deploy to development
./scripts/deploy.sh dev ghcr.io/parklense/auth-backend:latest

# Deploy to staging
./scripts/deploy.sh staging ghcr.io/parklense/auth-backend:v1.2.3

# Deploy to production (requires confirmation)
./scripts/deploy.sh prod ghcr.io/parklense/auth-backend:v1.2.3
```

### Environment-Specific Deployments

```bash
# Development
kubectl apply -k k8s/overlays/dev

# Staging
kubectl apply -k k8s/overlays/staging

# Production
kubectl apply -k k8s/overlays/prod
```

## 🔄 Rollback

### Emergency Rollback

Use the rollback script for quick rollbacks:

```bash
# Rollback to previous version
./scripts/rollback.sh prod

# Rollback to specific revision
./scripts/rollback.sh prod 5
```

### Manual Rollback

```bash
# Check rollout history
kubectl rollout history deployment/parklense-auth-backend -n prod-parklense-auth

# Rollback to previous revision
kubectl rollout undo deployment/parklense-auth-backend -n prod-parklense-auth

# Rollback to specific revision
kubectl rollout undo deployment/parklense-auth-backend -n prod-parklense-auth --to-revision=5
```

## 📊 Monitoring and Health Checks

### Health Endpoints

- **Health Check**: `GET /api/health/`
- **Readiness Check**: `GET /api/ready/`

### Monitoring Commands

```bash
# Check pod status
kubectl get pods -n prod-parklense-auth

# Check service status
kubectl get services -n prod-parklense-auth

# Check ingress status
kubectl get ingress -n prod-parklense-auth

# View logs
kubectl logs -f deployment/parklense-auth-backend -n prod-parklense-auth

# Check HPA status
kubectl get hpa -n prod-parklense-auth
```

## 🌐 Environment URLs

| Environment | URL | Purpose |
|-------------|-----|---------|
| Development | https://auth.heycampus.in | Development testing |
| Staging | https://staging-auth.parklense.com | QA and integration testing |
| Production | https://auth.parklense.com | Live production service |

## 🔧 Configuration

### Resource Allocation

| Environment | Backend CPU | Backend Memory | Worker CPU | Worker Memory |
|-------------|-------------|----------------|------------|---------------|
| Development | 0.5-1 CPU | 1-2 Gi | 0.25-0.5 CPU | 512Mi-1Gi |
| Staging | 1-2 CPU | 2-4 Gi | 0.5-1 CPU | 1-2 Gi |
| Production | 2-4 CPU | 4-8 Gi | 1-2 CPU | 2-4 Gi |

### Auto-scaling

- **Development**: 1-3 replicas
- **Staging**: 2-6 replicas  
- **Production**: 3-15 replicas

Auto-scaling triggers:
- CPU utilization > 70%
- Memory utilization > 80%

## 🔍 Troubleshooting

### Common Issues

#### 1. Pods not starting
```bash
# Check pod status
kubectl describe pod <pod-name> -n <namespace>

# Check events
kubectl get events -n <namespace> --sort-by='.lastTimestamp'
```

#### 2. Image pull errors
```bash
# Verify image exists
docker pull ghcr.io/parklense/auth-backend:tag

# Check secret configuration
kubectl get secret -n <namespace>
```

#### 3. Health check failures
```bash
# Check application logs
kubectl logs -f deployment/parklense-auth-backend -n <namespace>

# Test health endpoint directly
kubectl port-forward deployment/parklense-auth-backend 8080:80 -n <namespace>
curl http://localhost:8080/api/health/
```

#### 4. Database connection issues
```bash
# Check database connectivity
kubectl exec -it deployment/parklense-auth-backend -n <namespace> -- python manage.py dbshell
```

### Log Analysis

```bash
# View recent logs
kubectl logs --tail=100 deployment/parklense-auth-backend -n prod-parklense-auth

# Follow logs in real-time
kubectl logs -f deployment/parklense-auth-backend -n prod-parklense-auth

# View logs from all containers
kubectl logs deployment/parklense-auth-backend -n prod-parklense-auth --all-containers=true
```

## 🔒 Security Considerations

### Network Security
- All traffic is encrypted with TLS/SSL
- Network policies restrict inter-pod communication
- WAF protection on production ingress

### Secrets Security
- Secrets stored in AWS Secrets Manager
- No secrets in container images or git
- Secrets rotated regularly

### Pod Security
- Non-root user execution
- Read-only root filesystem where possible
- Security contexts and capabilities dropped

## 📚 Additional Resources

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [AWS EKS Documentation](https://docs.aws.amazon.com/eks/)
- [Kustomize Documentation](https://kustomize.io/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)

## 🆘 Support

For deployment issues or questions:

1. Check the troubleshooting section above
2. Review GitHub Actions logs
3. Check Slack #parklense-auth-alerts channel
4. Contact the DevOps team

## 📝 Contributing

1. Follow the existing structure and naming conventions
2. Test changes in development environment first
3. Update documentation for any configuration changes
4. Get approval for production changes

---

**⚠️ Important**: Always test deployments in development and staging before deploying to production! 