# Refactored Deployment Structure

This document outlines the completely refactored deployment structure that properly separates Auth and Vehicle services.

## 🏗️ **New Architecture Overview**

### **Complete Service Separation**
- **Auth Service**: Independent deployment with its own workflows, base configs, and overlays
- **Vehicle Service**: Independent deployment with its own workflows, base configs, and overlays
- **No Cross-Service Dependencies**: Each service deploys independently

## 📁 **Directory Structure**

```
Parklense-auth-service-Deployment/
├── .github/workflows/
│   ├── auth/                    # Auth service workflows only
│   │   ├── cd-dev.yaml         # Deploys auth service to dev
│   │   ├── cd-staging.yaml     # Deploys auth service to staging
│   │   └── cd-prod.yaml        # Deploys auth service to prod
│   └── vehicle-management/     # Vehicle service workflows only
│       ├── cd-dev.yaml         # Deploys vehicle service to dev
│       ├── cd-staging.yaml     # Deploys vehicle service to staging
│       └── cd-prod.yaml        # Deploys vehicle service to prod
├── k8s/
│   ├── base/
│   │   ├── auth/               # Auth service base configs only
│   │   │   ├── kustomization.yaml
│   │   │   ├── deployment/     # Auth deployments only
│   │   │   ├── services/       # Auth services only
│   │   │   ├── ingress/        # Auth ingress only
│   │   │   ├── secrets/        # Auth secrets only
│   │   │   ├── configmap/      # Auth configmaps only
│   │   │   └── autoscaling/    # Auth HPA only
│   │   └── vehicle/            # Vehicle service base configs only
│   │       ├── kustomization.yaml
│   │       ├── deployment/     # Vehicle deployments only
│   │       ├── services/       # Vehicle services only
│   │       ├── ingress/        # Vehicle ingress only
│   │       ├── secrets/        # Vehicle secrets only
│   │       ├── configmap/      # Vehicle configmaps only
│   │       └── autoscaling/    # Vehicle HPA only
│   └── overlays/
│       ├── auth/               # Auth service overlays
│       │   ├── dev/            # Auth dev environment
│       │   ├── staging/        # Auth staging environment
│       │   └── prod/           # Auth prod environment
│       └── vehicle/            # Vehicle service overlays
│           ├── dev/            # Vehicle dev environment
│           ├── staging/        # Vehicle staging environment
│           └── prod/           # Vehicle prod environment
```

## 🔄 **Deployment Workflows**

### **Auth Service Workflows**
- **Trigger**: Manual workflow dispatch
- **Inputs**: 
  - `image`: Auth service Docker image
  - `sha`: Git commit SHA
  - `commit_message`: Commit message
- **Actions**:
  - Updates auth service image tags only
  - Deploys to `k8s/overlays/auth/{env}`
  - Uses namespace: `{env}-parklense-auth`
  - Health check: `https://auth.parklensedev.com/api/health/`

### **Vehicle Service Workflows**
- **Trigger**: Manual workflow dispatch or from vehicle service repo
- **Inputs**:
  - `image`: Vehicle service Docker image
  - `sha`: Git commit SHA
  - `commit_message`: Commit message
- **Actions**:
  - Updates vehicle service image tags only
  - Deploys to `k8s/overlays/vehicle/{env}`
  - Uses namespace: `{env}-parklense-vehicle`
  - Health check: `https://vehicle.parklensedev.com/api/health/`

## 🌐 **Domain Configuration**

### **Development Environment**
- **Auth Service**: `https://auth.parklensedev.com`
- **Vehicle Service**: `https://vehicle.parklensedev.com`

### **Staging Environment**
- **Auth Service**: `https://auth.parklensedev.com`
- **Vehicle Service**: `https://vehicle.parklensedev.com`

### **Production Environment**
- **Auth Service**: `https://auth.parklense.com`
- **Vehicle Service**: `https://vehicle.parklense.com`

## 🔧 **Key Changes Made**

### 1. **Separated Base Configurations**
- **Auth Base**: Only contains auth service resources
- **Vehicle Base**: Only contains vehicle service resources
- **No Cross-References**: Each base is completely independent

### 2. **Updated Workflow Paths**
- **Auth Workflows**: Update `k8s/base/auth/deployment/` files
- **Vehicle Workflows**: Update `k8s/base/vehicle/deployment/` files
- **Deploy Paths**: 
  - Auth: `k8s/overlays/auth/{env}`
  - Vehicle: `k8s/overlays/vehicle/{env}`

### 3. **Namespace Separation**
- **Auth Service**: `{env}-parklense-auth`
- **Vehicle Service**: `{env}-parklense-vehicle`

### 4. **Certificate Configuration**
- **Certificate ARN**: `arn:aws:acm:ap-south-1:399600302704:certificate/6eb37406-7e5c-4612-9761-e49fcb1d3bf3`
- **Covers**: Both `auth.parklensedev.com` and `vehicle.parklensedev.com`

## 🚀 **Deployment Process**

### **Auth Service Deployment**
```bash
# 1. Auth service builds and pushes image
# 2. Triggers auth workflow manually
# 3. Updates auth service image tags
# 4. Deploys to auth overlay
# 5. Health check on auth domain
```

### **Vehicle Service Deployment**
```bash
# 1. Vehicle service builds and pushes image
# 2. Triggers vehicle workflow automatically
# 3. Updates vehicle service image tags
# 4. Deploys to vehicle overlay
# 5. Health check on vehicle domain
```

## 📊 **Resource Allocation**

### **Auth Service (Development)**
- **Backend**: 1 replica, 0.5-1 CPU, 1-2Gi memory
- **Celery Worker**: 1 replica, 0.25-0.5 CPU, 512Mi-1Gi memory
- **Celery Beat**: 1 replica, 0.1-0.25 CPU, 256-512Mi memory
- **Redis**: 1 replica, 0.1-0.25 CPU, 256-512Mi memory

### **Vehicle Service (Development)**
- **Backend**: 1 replica, 0.25-0.5 CPU, 512Mi-1Gi memory
- **HPA**: 1-3 replicas based on CPU/memory usage

## 🔍 **Monitoring and Health Checks**

### **Auth Service**
```bash
# Check auth service health
curl -f https://auth.parklensedev.com/api/health/

# Check auth pods
kubectl get pods -n dev-parklense-auth -l app=parklense-auth-backend

# Check auth services
kubectl get services -n dev-parklense-auth -l app=parklense-auth-backend
```

### **Vehicle Service**
```bash
# Check vehicle service health
curl -f https://vehicle.parklensedev.com/api/health/

# Check vehicle pods
kubectl get pods -n dev-parklense-vehicle -l app=parklense-vehicle-backend

# Check vehicle services
kubectl get services -n dev-parklense-vehicle -l app=parklense-vehicle-backend
```

## 🛠️ **Troubleshooting**

### **Common Issues**

1. **Namespace Issues**
   - Auth service: Check `dev-parklense-auth` namespace
   - Vehicle service: Check `dev-parklense-vehicle` namespace

2. **Image Path Issues**
   - Auth: `k8s/base/auth/deployment/`
   - Vehicle: `k8s/base/vehicle/deployment/`

3. **Deploy Path Issues**
   - Auth: `k8s/overlays/auth/dev`
   - Vehicle: `k8s/overlays/vehicle/dev`

4. **Domain Issues**
   - Auth: `auth.parklensedev.com`
   - Vehicle: `vehicle.parklensedev.com`

### **Rollback Procedures**

```bash
# Rollback auth service
kubectl rollout undo deployment/parklense-auth-backend -n dev-parklense-auth

# Rollback vehicle service
kubectl rollout undo deployment/parklense-vehicle-backend -n dev-parklense-vehicle
```

## ✅ **Benefits of Refactored Structure**

1. **Complete Separation**: No cross-service dependencies
2. **Independent Deployments**: Each service can be deployed independently
3. **Clear Ownership**: Each team owns their service deployment
4. **Easier Debugging**: Issues are isolated to specific services
5. **Scalability**: Services can scale independently
6. **Maintenance**: Easier to maintain and update individual services

## 🎯 **Next Steps**

1. **Test Deployments**: Deploy both services to verify separation works
2. **Update CI/CD**: Ensure vehicle service triggers correct workflow
3. **Monitor Health**: Set up monitoring for both services
4. **Documentation**: Update team documentation with new structure
5. **Training**: Train team on new deployment process

The refactored structure provides complete separation between Auth and Vehicle services while maintaining the same deployment capabilities! 🎉 