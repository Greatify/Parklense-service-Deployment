# Parklense API Gateway Setup Guide

## Overview

This guide provides comprehensive instructions for setting up AWS API Gateway to serve both the Parklense Authentication Service and Vehicle Management Service through a unified API Gateway.

## Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────────┐
│   Frontend      │    │   API Gateway    │    │   Load Balancers    │
│                 │    │                  │    │                     │
│ api.parklensedev│───▶│ Combined API     │───▶│ Auth ALB            │
│ .com            │    │ Gateway          │    │ (parklense-auth-    │
│                 │    │                  │    │  dev-alb-2046375436)│
│ vehicle.parklens│    │                  │    │                     │
│ edev.com        │    │                  │    │ Vehicle ALB         │
│                 │    │                  │    │ (parklense-vehicle- │
└─────────────────┘    └──────────────────┘    │  dev-alb-1618789014)│
                                               └─────────────────────┘
```

## Service Endpoints

### Authentication Service
- **Base URL**: `https://api.parklensedev.com`
- **ALB**: `parklense-auth-dev-alb-2046375436.ap-south-1.elb.amazonaws.com`
- **Host Header**: `api.parklensedev.com`

### Vehicle Service
- **Base URL**: `https://vehicle.parklensedev.com`
- **ALB**: `parklense-vehicle-dev-alb-1618789014.ap-south-1.elb.amazonaws.com`
- **Host Header**: `vehicle.parklensedev.com`

## API Gateway Configuration Files

### 1. Combined API Gateway (`combined-api-gateway.yaml`)
- **Purpose**: Single API Gateway serving both services
- **Routes**: 
  - `/health` → Auth Service
  - `/auth/*` → Auth Service
  - `/vehicle/*` → Vehicle Service
  - `/*` → Auth Service (fallback)

### 2. Vehicle-Only API Gateway (`vehicle-api-gateway.yaml`)
- **Purpose**: Dedicated API Gateway for vehicle service
- **Routes**: All vehicle-related endpoints

### 3. Auth-Only API Gateway (existing)
- **Purpose**: Dedicated API Gateway for auth service
- **Routes**: All authentication and profile endpoints

## Deployment Options

### Option 1: Combined API Gateway (Recommended)

```bash
# Deploy combined API Gateway
cd Parklense-Backend-service-Deployment
chmod +x deploy-combined-api-gateway.sh
./deploy-combined-api-gateway.sh
```

**Benefits:**
- Single API Gateway to manage
- Unified monitoring and logging
- Shared CORS configuration
- Cost-effective

**URL Structure:**
- Auth Service: `https://api.parklensedev.com/health`, `/auth/*`, `/api/v1/auth/*`
- Vehicle Service: `https://api.parklensedev.com/vehicle/health`, `/vehicle/api/v1/*`

### Option 2: Separate API Gateways

```bash
# Deploy vehicle-only API Gateway
chmod +x deploy-vehicle-api-gateway.sh
./deploy-vehicle-api-gateway.sh
```

**Benefits:**
- Service isolation
- Independent scaling
- Separate monitoring
- Service-specific configurations

## Configuration Details

### Host Header Mapping

The API Gateway uses different host headers to route requests to the correct ALB:

```yaml
# Auth Service Integration
requestParameters:
  overwrite:header.Host: "api.parklensedev.com"

# Vehicle Service Integration  
requestParameters:
  overwrite:header.Host: "vehicle.parklensedev.com"
```

### Route Patterns

#### Auth Service Routes
```
/health                    → Health check
/docs                      → Swagger UI
/schema                    → OpenAPI schema
/auth/{proxy+}             → Authentication endpoints
/profile/{proxy+}          → Profile endpoints
/api/v1/auth/{proxy+}      → API v1 auth endpoints
/api/v1/profile/{proxy+}   → API v1 profile endpoints
/static/{proxy+}           → Static files (Swagger UI)
/{proxy+}                  → Catch-all (fallback to auth)
```

#### Vehicle Service Routes
```
/vehicle/health                    → Health check
/vehicle/docs                      → Swagger UI
/vehicle/schema                    → OpenAPI schema
/vehicle/api/v1/health             → API v1 health
/vehicle/api/v1/vehicles           → Vehicle CRUD
/vehicle/api/v1/vehicles/{id}      → Individual vehicle
/vehicle/api/v1/vehicles/{id}/images → Vehicle images
/vehicle/api/v1/statistics         → Vehicle statistics
/vehicle/static/{proxy+}           → Static files
/vehicle/api/v1/{proxy+}           → Catch-all vehicle API
```

## Testing the Setup

### 1. Health Checks

```bash
# Auth Service Health
curl https://api.parklensedev.com/health

# Vehicle Service Health
curl https://api.parklensedev.com/vehicle/health
```

### 2. API Documentation

```bash
# Auth Service Docs
curl https://api.parklensedev.com/docs

# Vehicle Service Docs
curl https://api.parklensedev.com/vehicle/docs
```

### 3. Authentication Endpoints

```bash
# Login
curl -X POST https://api.parklensedev.com/auth/login/ \
  -H "Content-Type: application/json" \
  -d '{"email":"user@example.com","password":"password"}'

# API v1 Login
curl -X POST https://api.parklensedev.com/api/v1/auth/login/ \
  -H "Content-Type: application/json" \
  -d '{"email":"user@example.com","password":"password"}'
```

### 4. Vehicle Endpoints

```bash
# List vehicles
curl https://api.parklensedev.com/vehicle/api/v1/vehicles/

# Create vehicle
curl -X POST https://api.parklensedev.com/vehicle/api/v1/vehicles/ \
  -H "Content-Type: application/json" \
  -d '{"license_plate":"ABC123","vehicle_type":"car","make":"Toyota","model":"Camry","year":2020}'

# Get vehicle statistics
curl https://api.parklensedev.com/vehicle/api/v1/statistics/
```

## DNS Configuration

### Combined API Gateway
```bash
# Point api.parklensedev.com to the API Gateway URL
# Example: api.parklensedev.com CNAME d1234567890.execute-api.ap-south-1.amazonaws.com
```

### Separate API Gateways
```bash
# Auth Service
api.parklensedev.com CNAME auth-api-gateway-url.execute-api.ap-south-1.amazonaws.com

# Vehicle Service  
vehicle.parklensedev.com CNAME vehicle-api-gateway-url.execute-api.ap-south-1.amazonaws.com
```

## Monitoring and Troubleshooting

### 1. API Gateway Logs

Enable CloudWatch logs for API Gateway:

```bash
# Enable logging
aws apigatewayv2 update-stage \
  --api-id YOUR_API_ID \
  --stage-name dev \
  --default-route-settings '{"DetailedMetricsEnabled":true,"LoggingLevel":"INFO"}' \
  --region ap-south-1
```

### 2. Common Issues

#### Issue: 404 Not Found
**Cause**: Route not configured in API Gateway
**Solution**: Check route configuration in OpenAPI spec

#### Issue: 403 Forbidden
**Cause**: Missing or incorrect Host header
**Solution**: Verify `overwrite:header.Host` parameter mapping

#### Issue: 500 Internal Server Error
**Cause**: ALB health check failing or service down
**Solution**: Check ALB target group health and service logs

#### Issue: CORS Errors
**Cause**: CORS not configured properly
**Solution**: Verify CORS configuration in API Gateway

### 3. Health Check Commands

```bash
# Check ALB directly
curl -H "Host: api.parklensedev.com" http://parklense-auth-dev-alb-2046375436.ap-south-1.elb.amazonaws.com/health/
curl -H "Host: vehicle.parklensedev.com" http://parklense-vehicle-dev-alb-1618789014.ap-south-1.elb.amazonaws.com/health/

# Check API Gateway
curl https://api.parklensedev.com/health
curl https://api.parklensedev.com/vehicle/health
```

## Security Considerations

### 1. API Gateway Security
- Use HTTPS only
- Configure proper CORS policies
- Implement rate limiting
- Enable CloudWatch logging

### 2. ALB Security
- Use security groups to restrict access
- Enable HTTPS termination
- Configure health checks

### 3. Service Security
- Implement proper authentication
- Use JWT tokens for API access
- Validate input data
- Log security events

## Cost Optimization

### 1. API Gateway Costs
- Use HTTP APIs (cheaper than REST APIs)
- Optimize route configuration
- Monitor usage patterns

### 2. ALB Costs
- Use Application Load Balancers efficiently
- Monitor target group health
- Optimize instance types

## Maintenance

### 1. Regular Tasks
- Monitor API Gateway metrics
- Check ALB health status
- Review CloudWatch logs
- Update SSL certificates

### 2. Scaling
- Monitor API Gateway throttling
- Scale ALB target groups
- Optimize route configurations

## Support and Documentation

### Useful Commands

```bash
# List API Gateways
aws apigatewayv2 get-apis --region ap-south-1

# Get API details
aws apigatewayv2 get-api --api-id YOUR_API_ID --region ap-south-1

# Get routes
aws apigatewayv2 get-routes --api-id YOUR_API_ID --region ap-south-1

# Get integrations
aws apigatewayv2 get-integrations --api-id YOUR_API_ID --region ap-south-1
```

### Documentation Links
- [AWS API Gateway HTTP APIs](https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api.html)
- [API Gateway Integration](https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api-develop-integrations.html)
- [OpenAPI Specification](https://swagger.io/specification/)

## Conclusion

This setup provides a robust, scalable, and maintainable API Gateway configuration for both Parklense services. The combined approach offers the best balance of functionality, cost, and manageability.

For production deployment, consider:
1. Setting up proper monitoring and alerting
2. Implementing rate limiting and throttling
3. Configuring SSL certificates
4. Setting up backup and disaster recovery
5. Implementing proper logging and audit trails 