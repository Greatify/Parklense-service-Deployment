# Parklense API Gateway Configuration

This document describes the complete API Gateway configuration for the Parklense platform, including both Authentication and Vehicle Management services.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    API Gateway (api.parklensedev.com)           │
├─────────────────────────────────────────────────────────────────┤
│  /auth/*     →  Auth Service ALB                                │
│  /profile/*  →  Auth Service ALB                                │
│  /vehicle/*  →  Auth Service ALB (proxied to Vehicle Service)   │
│  /health     →  Auth Service ALB                                │
│  /docs       →  Auth Service ALB (Swagger UI)                   │
│  /schema     →  Auth Service ALB (OpenAPI Schema)               │
└─────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────┐
│              Auth Service ALB                                   │
│  (parklense-auth-dev-alb-887676365.ap-south-1.elb.amazonaws.com)│
├─────────────────────────────────────────────────────────────────┤
│  Django Auth Service (Kubernetes)                               │
│  - Authentication endpoints                                     │
│  - Profile management                                           │
│  - Health checks                                               │
│  - API documentation                                           │
└─────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────┐
│              Vehicle Service ALB                                │
│  (internal-parklense-vehicle-dev-alb-760645548.ap-south-1.elb)  │
├─────────────────────────────────────────────────────────────────┤
│  Django Vehicle Service (Kubernetes)                            │
│  - Vehicle management endpoints                                 │
│  - Vehicle registration                                         │
│  - Vehicle images                                               │
└─────────────────────────────────────────────────────────────────┘
```

## Configuration Files

### 1. `api-gateway-complete.yaml`
Complete API Gateway configuration with all endpoints, CORS, and advanced features.

### 2. `api-gateway-corrected.yaml`
Previous configuration with basic routing.

### 3. `api-gateway-auth-only.yaml`
Auth service only configuration.

## Endpoints

### Authentication Service (`/auth/*`)

| Endpoint | Method | Description | Example |
|----------|--------|-------------|---------|
| `/auth/login/` | POST | User login | `https://api.parklensedev.com/auth/login/` |
| `/auth/register/` | POST | User registration | `https://api.parklensedev.com/auth/register/` |
| `/auth/otp/request/` | POST | Request OTP | `https://api.parklensedev.com/auth/otp/request/` |
| `/auth/otp/verify/` | POST | Verify OTP | `https://api.parklensedev.com/auth/otp/verify/` |
| `/auth/logout/` | POST | User logout | `https://api.parklensedev.com/auth/logout/` |
| `/auth/token/refresh/` | POST | Refresh JWT token | `https://api.parklensedev.com/auth/token/refresh/` |
| `/auth/google/` | POST | Google OAuth | `https://api.parklensedev.com/auth/google/` |
| `/auth/verify-email/` | POST | Email verification | `https://api.parklensedev.com/auth/verify-email/` |
| `/auth/password/reset/` | POST | Password reset request | `https://api.parklensedev.com/auth/password/reset/` |
| `/auth/health` | GET | Auth service health | `https://api.parklensedev.com/auth/health` |

### Profile Service (`/profile/*`)

| Endpoint | Method | Description | Example |
|----------|--------|-------------|---------|
| `/profile/` | GET/PUT | User profile | `https://api.parklensedev.com/profile/` |
| `/profile/avatar/` | POST | Upload avatar | `https://api.parklensedev.com/profile/avatar/` |

### Vehicle Service (`/vehicle/*`)

| Endpoint | Method | Description | Example |
|----------|--------|-------------|---------|
| `/vehicle/api/v1/vehicles/` | GET/POST | Vehicle list/create | `https://api.parklensedev.com/vehicle/api/v1/vehicles/` |
| `/vehicle/api/v1/vehicles/{id}/` | GET/PUT/DELETE | Vehicle details | `https://api.parklensedev.com/vehicle/api/v1/vehicles/{id}/` |
| `/vehicle/api/v1/vehicles/{id}/images/` | POST | Upload vehicle image | `https://api.parklensedev.com/vehicle/api/v1/vehicles/{id}/images/` |
| `/vehicle/health` | GET | Vehicle service health | `https://api.parklensedev.com/vehicle/health` |

### API v1 Endpoints (Backward Compatibility)

| Endpoint | Method | Description | Example |
|----------|--------|-------------|---------|
| `/api/v1/auth/*` | ANY | Auth service v1 | `https://api.parklensedev.com/api/v1/auth/login/` |
| `/api/v1/profile/*` | ANY | Profile service v1 | `https://api.parklensedev.com/api/v1/profile/` |
| `/api/v1/vehicle/*` | ANY | Vehicle service v1 | `https://api.parklensedev.com/api/v1/vehicle/vehicles/` |

### Utility Endpoints

| Endpoint | Method | Description | Example |
|----------|--------|-------------|---------|
| `/health` | GET | Global health check | `https://api.parklensedev.com/health` |
| `/docs` | GET | API documentation | `https://api.parklensedev.com/docs` |
| `/schema` | GET | OpenAPI schema | `https://api.parklensedev.com/schema` |

## CORS Configuration

The API Gateway is configured with comprehensive CORS support:

### Allowed Origins
- `https://parklensedev.com`
- `https://www.parklensedev.com`
- `https://app.parklensedev.com`
- `https://admin.parklensedev.com`
- `http://localhost:3000` (development)
- `http://localhost:3001` (development)
- `http://localhost:8080` (development)

### Allowed Methods
- GET, POST, PUT, DELETE, PATCH, OPTIONS

### Allowed Headers
- Content-Type, Authorization, X-Api-Key
- X-Request-ID, X-Correlation-ID
- Mobile headers: X-Platform, X-App-Version, X-Device-ID, etc.

### Exposed Headers
- X-Correlation-ID, X-Response-Time, X-API-Version, X-Request-ID

## Rate Limiting

Two usage plans are configured:

### Basic Plan
- Rate Limit: 50 requests/second
- Burst Limit: 100 requests
- Daily Quota: 10,000 requests

### Premium Plan
- Rate Limit: 100 requests/second
- Burst Limit: 200 requests
- Daily Quota: 50,000 requests

## Deployment

### Prerequisites
1. AWS CLI configured with appropriate permissions
2. Python 3.x installed (for YAML validation)
3. Custom domain certificate in ACM
4. Route 53 hosted zone for `parklensedev.com`

### Quick Deployment

```bash
# Navigate to the deployment directory
cd Parklense-Backend-service-Deployment

# Deploy the complete API Gateway
./scripts/deploy-api-gateway-complete.sh
```

### Manual Deployment

```bash
# 1. Create/Update API Gateway
aws apigateway import-rest-api \
    --body file://api-gateway-complete.yaml \
    --region ap-south-1

# 2. Deploy to stage
aws apigateway create-deployment \
    --rest-api-id <API_ID> \
    --stage-name dev \
    --region ap-south-1

# 3. Setup custom domain mapping
aws apigateway create-base-path-mapping \
    --domain-name api.parklensedev.com \
    --rest-api-id <API_ID> \
    --stage dev \
    --region ap-south-1
```

### Script Options

```bash
# Show help
./scripts/deploy-api-gateway-complete.sh --help

# Test existing endpoints only
./scripts/deploy-api-gateway-complete.sh --test-only

# Skip custom domain setup
./scripts/deploy-api-gateway-complete.sh --skip-domain

# Skip usage plans setup
./scripts/deploy-api-gateway-complete.sh --skip-plans
```

## Testing

### Health Checks
```bash
# Global health
curl https://api.parklensedev.com/health

# Auth service health
curl https://api.parklensedev.com/auth/health

# Vehicle service health
curl https://api.parklensedev.com/vehicle/health
```

### Authentication
```bash
# Login
curl -X POST https://api.parklensedev.com/auth/login/ \
  -H "Content-Type: application/json" \
  -d '{"email": "user@example.com", "password": "password123"}'

# Register
curl -X POST https://api.parklensedev.com/auth/register/ \
  -H "Content-Type: application/json" \
  -d '{"email": "newuser@example.com", "password": "password123", "first_name": "John", "last_name": "Doe"}'
```

### Vehicle Management
```bash
# List vehicles (requires authentication)
curl -X GET https://api.parklensedev.com/vehicle/api/v1/vehicles/ \
  -H "Authorization: Bearer <JWT_TOKEN>"

# Create vehicle
curl -X POST https://api.parklensedev.com/vehicle/api/v1/vehicles/ \
  -H "Authorization: Bearer <JWT_TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{"license_plate": "ABC123", "vehicle_type": "car", "make": "Toyota", "model": "Camry"}'
```

## Monitoring

### CloudWatch Metrics
- Request count
- Latency
- Error rate
- Cache hit/miss ratio

### Logs
- Access logs in CloudWatch Logs
- Error logs with detailed information
- Custom metrics for business KPIs

### Alerts
- High error rate (>5%)
- High latency (>2 seconds)
- Rate limit exceeded
- Service unavailability

## Security

### Authentication
- JWT tokens for API access
- OAuth 2.0 for third-party integrations
- API keys for service-to-service communication

### Authorization
- Role-based access control (RBAC)
- Resource-level permissions
- Organization-based access control

### Data Protection
- All data encrypted in transit (TLS 1.2+)
- Sensitive data encrypted at rest
- PII handling compliance (GDPR)

## Troubleshooting

### Common Issues

1. **CORS Errors**
   - Check allowed origins in CORS configuration
   - Verify preflight requests are handled correctly

2. **Rate Limiting**
   - Check usage plan configuration
   - Monitor CloudWatch metrics for throttling

3. **Authentication Issues**
   - Verify JWT token format and expiration
   - Check authorization headers

4. **Service Unavailable**
   - Check ALB health status
   - Verify Kubernetes pod status
   - Check service endpoints

### Debug Commands

```bash
# Check API Gateway status
aws apigateway get-rest-api --rest-api-id <API_ID>

# Check deployment status
aws apigateway get-deployments --rest-api-id <API_ID>

# Check custom domain
aws apigateway get-domain-name --domain-name api.parklensedev.com

# Test endpoint directly
curl -v https://api.parklensedev.com/health
```

## Support

For issues or questions:
1. Check CloudWatch logs for detailed error information
2. Review API Gateway metrics in AWS Console
3. Contact DevOps team with error details and request IDs
4. Check service health endpoints for individual service status

## Version History

- **v1.0.0** (2025-07-15): Initial complete configuration
  - Added all auth and vehicle endpoints
  - Configured CORS for all domains
  - Added rate limiting and usage plans
  - Included comprehensive health checks
  - Added API documentation endpoints 