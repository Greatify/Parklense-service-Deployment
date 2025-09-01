# Parklense API Gateway Setup

## Overview
Unified API Gateway configuration for Auth and Vehicle services using single domain: `api.parklensedev.com`

## Service Endpoints

### Auth Service (`parklense-auth-dev-alb-*.elb.amazonaws.com`)
- **Base URL**: `api.parklensedev.com`
- **Health**: `/health/` 
- **Admin**: `/admin/`
- **API**: `/api/v1/auth/`, `/api/v1/profile/`
- **Docs**: `/api/schema/`, `/api/v1/swagger/`, `/api/v1/redoc/`

### Vehicle Service (`parklense-vehicle-dev-alb-*.elb.amazonaws.com`) 
- **Base URL**: `api.parklensedev.com`
- **Health**: `/health/`
- **API**: `/api/v1/vehicles/`
- **Docs**: `/api/schema/`, `/api/docs/`, `/api/redoc/`

## Required API Gateway Routes

```yaml
# 1. Auth Service Routes
/admin:
  ANY → http://parklense-auth-dev-alb-*.elb.amazonaws.com/admin
  Host: api.parklensedev.com

/admin/{proxy+}:
  ANY → http://parklense-auth-dev-alb-*.elb.amazonaws.com/admin/{proxy}
  Host: api.parklensedev.com

/api/v1/auth:
  ANY → http://parklense-auth-dev-alb-*.elb.amazonaws.com/api/v1/auth/
  Host: api.parklensedev.com

/api/v1/auth/{proxy+}:
  ANY → http://parklense-auth-dev-alb-*.elb.amazonaws.com/api/v1/auth/{proxy}
  Host: api.parklensedev.com

/api/v1/profile:
  ANY → http://parklense-auth-dev-alb-*.elb.amazonaws.com/api/v1/profile/
  Host: api.parklensedev.com

/api/v1/profile/{proxy+}:
  ANY → http://parklense-auth-dev-alb-*.elb.amazonaws.com/api/v1/profile/{proxy}
  Host: api.parklensedev.com

# 2. Vehicle Service Routes  
/api/v1/vehicles:
  ANY → http://parklense-vehicle-dev-alb-*.elb.amazonaws.com/api/v1/vehicles/
  Host: api.parklensedev.com

/api/v1/vehicles/{proxy+}:
  ANY → http://parklense-vehicle-dev-alb-*.elb.amazonaws.com/api/v1/vehicles/{proxy}
  Host: api.parklensedev.com

/api/v1/vehicle-types:
  ANY → http://parklense-vehicle-dev-alb-*.elb.amazonaws.com/api/v1/vehicle-types/
  Host: api.parklensedev.com

/api/v1/users/initialize:
  ANY → http://parklense-vehicle-dev-alb-*.elb.amazonaws.com/api/v1/users/initialize/
  Host: api.parklensedev.com

# 3. Health Routes (Service-Specific)
/health/auth:
  GET → http://parklense-auth-dev-alb-*.elb.amazonaws.com/api/v1/health/
  Host: api.parklensedev.com

/health/vehicles:
  GET → http://parklense-vehicle-dev-alb-*.elb.amazonaws.com/health/
  Host: api.parklensedev.com

/health:
  GET → http://parklense-auth-dev-alb-*.elb.amazonaws.com/api/v1/health/
  Host: api.parklensedev.com (defaults to auth service)

# 4. Documentation Routes (Service-Specific)
/docs/auth/schema:
  GET → http://parklense-auth-dev-alb-*.elb.amazonaws.com/api/schema/
  Host: api.parklensedev.com

/docs/vehicles/schema:
  GET → http://parklense-vehicle-dev-alb-*.elb.amazonaws.com/api/schema/
  Host: api.parklensedev.com

/docs/auth:
  GET → http://parklense-auth-dev-alb-*.elb.amazonaws.com/api/v1/swagger/
  Host: api.parklensedev.com

/docs/vehicles:
  GET → http://parklense-vehicle-dev-alb-*.elb.amazonaws.com/api/docs/
  Host: api.parklensedev.com

/docs/auth/redoc:
  GET → http://parklense-auth-dev-alb-*.elb.amazonaws.com/api/v1/redoc/
  Host: api.parklensedev.com

/docs/vehicles/redoc:
  GET → http://parklense-vehicle-dev-alb-*.elb.amazonaws.com/api/redoc/
  Host: api.parklensedev.com

# 5. Legacy Routes (Backward Compatibility)
/api/schema:
  GET → http://parklense-auth-dev-alb-*.elb.amazonaws.com/api/schema/
  Host: api.parklensedev.com (defaults to auth service)
```

## Configuration Steps

1. **Update ALB Target Groups**
   - Ensure both ALBs accept `Host: api.parklensedev.com` 
   - Update ingress configurations completed ✅

2. **Create API Gateway Routes**
   - Add all base routes (without `{proxy+}`)
   - Add all proxy routes (with `{proxy+}`)
   - Set correct Host headers: `api.parklensedev.com`

3. **Test Endpoints**
   ```bash
   # Auth Service
   curl https://api.parklensedev.com/api/v1/auth/health/
   curl https://api.parklensedev.com/admin/
   
   # Vehicle Service  
   curl https://api.parklensedev.com/api/v1/vehicles/
   curl https://api.parklensedev.com/api/v1/vehicle-types/
   
   # Documentation
   curl https://api.parklensedev.com/api/v1/swagger/
   curl https://api.parklensedev.com/api/docs/
   ```

## Notes
- All routes use HTTP proxy integration
- Timeout: 30 seconds
- Both services expect Host: `api.parklensedev.com`  
- Base routes handle exact matches (e.g., `/api/v1/vehicles`)
- Proxy routes handle sub-paths (e.g., `/api/v1/vehicles/123`)
