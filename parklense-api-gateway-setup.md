# Parklense API Gateway Setup Guide

## 🎯 Current Infrastructure

Based on your `kubectl get ingress` output, you have:

```bash
# Auth Service ALB
parklense-auth-ingress      → api.parklensedev.com       
→ parklense-auth-dev-alb-2046375436.ap-south-1.elb.amazonaws.com

# Vehicle Service ALB  
parklense-vehicle-ingress   → vehicle.parklensedev.com   
→ parklense-vehicle-dev-alb-1618789014.ap-south-1.elb.amazonaws.com

# Frontend ALB
parklens-ingress           → parklensedev.com           
→ parklens-frontend-dev-alb-314219590.ap-south-1.elb.amazonaws.com
```

## 🚀 API Gateway Setup Steps

### Step 1: Upload Configuration to API Gateway

1. **Go to AWS Console** → **API Gateway**
2. **Find your existing API Gateway**: "Parklense Backend Service - Dev"
3. **Import the configuration**:
   - Click **Actions** → **Import**
   - Select **"Swagger / OpenAPI 3"**
   - Upload the `api-gateway-complete.yaml` file
   - Choose **"Replace entire API"**

### Step 2: Route Configuration

Your `api-gateway-complete.yaml` already has the correct integrations:

#### **Auth Service Routes** (`/auth/*`, `/profile/*`)
```yaml
uri: http://parklense-auth-dev-alb-2046375436.ap-south-1.elb.amazonaws.com/auth/{proxy}
```

#### **Vehicle Service Routes** (`/vehicle/*`)
```yaml
uri: http://parklense-vehicle-dev-alb-1618789014.ap-south-1.elb.amazonaws.com/{proxy}
```

#### **Legacy API v1 Routes**
```yaml
# Auth v1
uri: http://parklense-auth-dev-alb-2046375436.ap-south-1.elb.amazonaws.com/api/v1/auth/{proxy}

# Profile v1  
uri: http://parklense-auth-dev-alb-2046375436.ap-south-1.elb.amazonaws.com/api/v1/profile/{proxy}

# Vehicle v1
uri: http://parklense-vehicle-dev-alb-1618789014.ap-south-1.elb.amazonaws.com/api/v1/{proxy}
```

## 🔧 Manual Integration Setup (Alternative)

If you prefer to set up manually in AWS Console:

### For `/api/v1/profile/{proxy+}` route:

1. **Integration Type**: HTTP
2. **HTTP Method**: ANY
3. **Integration HTTP Method**: ANY  
4. **Endpoint URL**: `http://parklense-auth-dev-alb-2046375436.ap-south-1.elb.amazonaws.com/api/v1/profile/{proxy}`
5. **Path Override**: Leave empty
6. **Query String**: Pass through
7. **Headers**: Add these request parameters:
   ```
   integration.request.header.Host: 'api.parklensedev.com'
   integration.request.path.proxy: method.request.path.proxy
   ```

### Response Configuration:
```yaml
Method Response Headers:
- Access-Control-Allow-Origin: '*'
- Access-Control-Allow-Methods: 'GET,POST,PUT,DELETE,OPTIONS'
- Access-Control-Allow-Headers: 'Content-Type,Authorization,X-API-Key'

Integration Response Headers:
- Access-Control-Allow-Origin: '*'
- Access-Control-Allow-Methods: 'GET,POST,PUT,DELETE,OPTIONS'  
- Access-Control-Allow-Headers: 'Content-Type,Authorization,X-API-Key'
```

## 📋 Complete Route Mapping

After setup, your API Gateway will route:

```bash
# Health & Documentation
https://api.parklensedev.com/health          → Auth ALB (/health/)
https://api.parklensedev.com/docs            → Auth ALB (/api/v1/swagger/)
https://api.parklensedev.com/schema          → Auth ALB (/api/schema/)

# Auth Service (Direct Routes - Cleaner URLs)
https://api.parklensedev.com/auth/login/     → Auth ALB (/auth/login/)
https://api.parklensedev.com/auth/register/  → Auth ALB (/auth/register/)
https://api.parklensedev.com/auth/otp/send/  → Auth ALB (/auth/otp/send/)

# Profile Service (Direct Routes)
https://api.parklensedev.com/profile/        → Auth ALB (/profile/)

# Vehicle Service (Direct Routes - FIXED!)
https://api.parklensedev.com/vehicle/vehicles/ → Vehicle ALB (/api/v1/vehicles/)

# Legacy API v1 (Backward Compatible)
https://api.parklensedev.com/api/v1/auth/*      → Auth ALB (/api/v1/auth/*)
https://api.parklensedev.com/api/v1/profile/*   → Auth ALB (/api/v1/profile/*)
https://api.parklensedev.com/api/v1/vehicles/*  → Vehicle ALB (/api/v1/*)
```

## 🔧 Key Fixes Applied

✅ **Vehicle Service ALB**: Now correctly points to `parklense-vehicle-dev-alb-1618789014.ap-south-1.elb.amazonaws.com`  
✅ **Vehicle Routes**: Fixed path mapping from `/vehicle/{proxy+}` to `/api/v1/{proxy}` on vehicle ALB  
✅ **Host Headers**: Vehicle service gets `vehicle.parklensedev.com`, Auth gets `api.parklensedev.com`  
✅ **URL Structure**: Matches actual Django URL configurations  
✅ **Security**: Added JWT auth requirements for protected endpoints

## 🧪 Testing After Setup

### Test Health Endpoint
```bash
curl -X GET "https://api.parklensedev.com/health"
```

### Test Auth Endpoints
```bash
# New auth route
curl -X POST "https://api.parklensedev.com/auth/login/" \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"test123"}'

# Legacy auth route (should still work)
curl -X POST "https://api.parklensedev.com/api/v1/auth/login/" \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"test123"}'
```

### Test Profile Endpoints
```bash
# New profile route
curl -X GET "https://api.parklensedev.com/profile/" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"

# Legacy profile route
curl -X GET "https://api.parklensedev.com/api/v1/profile/" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

### Test Vehicle Endpoints
```bash
# New vehicle route (FIXED!)
curl -X GET "https://api.parklensedev.com/vehicle/vehicles/" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"

# Legacy vehicle route (FIXED!)
curl -X GET "https://api.parklensedev.com/api/v1/vehicles/" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"

# Test vehicle creation
curl -X POST "https://api.parklensedev.com/api/v1/vehicles/" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "license_plate": "TEST123",
    "state_province": "CA",
    "country": "US",
    "vehicle_type": "car"
  }'
```

## 🔍 Troubleshooting

### Common Issues:

1. **502 Bad Gateway**: Check ALB health and security groups
2. **CORS Errors**: Verify CORS configuration in API Gateway
3. **404 Not Found**: Ensure routes are deployed after import
4. **Authentication Issues**: Check JWT token format

### Debug Commands:
```bash
# Test ALBs directly
curl -H "Host: api.parklensedev.com" \
  http://parklense-auth-dev-alb-2046375436.ap-south-1.elb.amazonaws.com/health/

curl -H "Host: vehicle.parklensedev.com" \
  http://parklense-vehicle-dev-alb-1618789014.ap-south-1.elb.amazonaws.com/health/
```

## ✅ Final Steps

1. **Import the YAML** configuration to your API Gateway
2. **Deploy** to your dev stage
3. **Test** all endpoints using the commands above
4. **Update** your frontend to use `api.parklensedev.com`
5. **Monitor** CloudWatch metrics for performance

Your API Gateway will act as a unified entry point, routing requests to the appropriate ALBs based on the URL path! 🚀
