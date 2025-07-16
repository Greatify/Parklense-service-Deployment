#!/bin/bash

# Parklense API Gateway Deployment Script
# This script deploys the combined API Gateway for Auth and Vehicle services

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
REGION="ap-south-1"
DOMAIN_NAME="api.parklensedev.com"
STAGE_NAME="dev"
API_GATEWAY_FILE="api-gateway-complete.yaml"

# ALB URLs (update these with your actual ALB URLs)
AUTH_ALB_URL="parklense-auth-dev-alb-2046375436.ap-south-1.elb.amazonaws.com"
VEHICLE_ALB_URL="parklense-vehicle-dev-alb-1618789014.ap-south-1.elb.amazonaws.com"

# Certificate ARN (update with your actual certificate ARN)
CERTIFICATE_ARN="arn:aws:acm:ap-south-1:399600302704:certificate/6eb37406-7e5c-4612-9761-e49fcb1d3bf3"

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if AWS CLI is configured
check_aws_cli() {
    print_status "Checking AWS CLI configuration..."
    
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed. Please install it first."
        exit 1
    fi
    
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS CLI is not configured. Please run 'aws configure' first."
        exit 1
    fi
    
    print_success "AWS CLI is configured"
}

# Function to validate YAML file
validate_yaml() {
    print_status "Validating API Gateway configuration..."
    
    if [ ! -f "$API_GATEWAY_FILE" ]; then
        print_error "API Gateway configuration file not found: $API_GATEWAY_FILE"
        exit 1
    fi
    
    # Check if yamllint is available
    if command -v yamllint &> /dev/null; then
        yamllint "$API_GATEWAY_FILE"
        print_success "YAML validation passed"
    else
        print_warning "yamllint not found, skipping YAML validation"
    fi
}

# Function to create/update API Gateway
deploy_api_gateway() {
    print_status "Deploying API Gateway..."
    
    # Check if API Gateway already exists
    EXISTING_API=$(aws apigateway get-rest-apis --region "$REGION" --query "items[?name=='Parklense API Gateway'].id" --output text)
    
    if [ -n "$EXISTING_API" ] && [ "$EXISTING_API" != "None" ]; then
        print_status "Updating existing API Gateway: $EXISTING_API"
        
        # Import the updated configuration
        aws apigateway put-rest-api \
            --rest-api-id "$EXISTING_API" \
            --mode overwrite \
            --body file://"$API_GATEWAY_FILE" \
            --region "$REGION"
        
        API_ID="$EXISTING_API"
    else
        print_status "Creating new API Gateway..."
        
        # Create new API Gateway
        API_ID=$(aws apigateway import-rest-api \
            --body file://"$API_GATEWAY_FILE" \
            --region "$REGION" \
            --query 'id' \
            --output text)
    fi
    
    print_success "API Gateway ID: $API_ID"
    
    # Deploy to stage
    print_status "Deploying to $STAGE_NAME stage..."
    aws apigateway create-deployment \
        --rest-api-id "$API_ID" \
        --stage-name "$STAGE_NAME" \
        --region "$REGION" \
        --description "Deployment $(date +%Y-%m-%d_%H-%M-%S)"
    
    print_success "API Gateway deployed successfully"
    echo "API Gateway URL: https://$API_ID.execute-api.$REGION.amazonaws.com/$STAGE_NAME"
}

# Function to setup custom domain
setup_custom_domain() {
    print_status "Setting up custom domain: $DOMAIN_NAME"
    
    # Check if domain name already exists
    EXISTING_DOMAIN=$(aws apigateway get-domain-names --region "$REGION" --query "items[?domainName=='$DOMAIN_NAME'].domainName" --output text)
    
    if [ -n "$EXISTING_DOMAIN" ] && [ "$EXISTING_DOMAIN" != "None" ]; then
        print_status "Custom domain already exists, updating..."
        
        # Update domain name
        aws apigateway update-domain-name \
            --domain-name "$DOMAIN_NAME" \
            --patch-operations op=replace,path=/certificateArn,value="$CERTIFICATE_ARN" \
            --region "$REGION"
    else
        print_status "Creating custom domain..."
        
        # Create domain name
        aws apigateway create-domain-name \
            --domain-name "$DOMAIN_NAME" \
            --certificate-arn "$CERTIFICATE_ARN" \
            --region "$REGION"
    fi
    
    # Setup base path mapping
    print_status "Setting up base path mapping..."
    
    # Remove existing mapping if it exists
    aws apigateway delete-base-path-mapping \
        --domain-name "$DOMAIN_NAME" \
        --base-path "(none)" \
        --region "$REGION" 2>/dev/null || true
    
    # Create new mapping
    aws apigateway create-base-path-mapping \
        --domain-name "$DOMAIN_NAME" \
        --rest-api-id "$API_ID" \
        --stage "$STAGE_NAME" \
        --region "$REGION"
    
    print_success "Custom domain setup completed"
    echo "API Gateway URL: https://$DOMAIN_NAME"
}

# Function to test endpoints
test_endpoints() {
    print_status "Testing API Gateway endpoints..."
    
    BASE_URL="https://$DOMAIN_NAME"
    
    # Test health endpoint
    print_status "Testing health endpoint..."
    if curl -f -s "$BASE_URL/health" > /dev/null; then
        print_success "Health endpoint is working"
    else
        print_error "Health endpoint failed"
    fi
    
    # Test auth endpoint
    print_status "Testing auth endpoint..."
    if curl -f -s "$BASE_URL/auth/health/" > /dev/null; then
        print_success "Auth endpoint is working"
    else
        print_error "Auth endpoint failed"
    fi
    
    # Test vehicle endpoint
    print_status "Testing vehicle endpoint..."
    if curl -f -s "$BASE_URL/vehicle/health/" > /dev/null; then
        print_success "Vehicle endpoint is working"
    else
        print_error "Vehicle endpoint failed"
    fi
    
    # Test CORS
    print_status "Testing CORS..."
    if curl -f -s -H "Origin: https://parklensedev.com" \
        -H "Access-Control-Request-Method: GET" \
        -H "Access-Control-Request-Headers: Content-Type" \
        -X OPTIONS "$BASE_URL/health" > /dev/null; then
        print_success "CORS is working"
    else
        print_error "CORS test failed"
    fi
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --help              Show this help message"
    echo "  --test-only         Only test existing endpoints"
    echo "  --skip-domain       Skip custom domain setup"
    echo "  --skip-tests        Skip endpoint testing"
    echo ""
    echo "Examples:"
    echo "  $0                  # Full deployment"
    echo "  $0 --test-only      # Test existing endpoints"
    echo "  $0 --skip-domain    # Deploy without custom domain"
}

# Main execution
main() {
    echo "🚀 Parklense API Gateway Deployment"
    echo "=================================="
    
    # Parse command line arguments
    TEST_ONLY=false
    SKIP_DOMAIN=false
    SKIP_TESTS=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --help)
                show_usage
                exit 0
                ;;
            --test-only)
                TEST_ONLY=true
                shift
                ;;
            --skip-domain)
                SKIP_DOMAIN=true
                shift
                ;;
            --skip-tests)
                SKIP_TESTS=true
                shift
                ;;
            *)
                print_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    if [ "$TEST_ONLY" = true ]; then
        print_status "Test-only mode enabled"
        test_endpoints
        exit 0
    fi
    
    # Check prerequisites
    check_aws_cli
    validate_yaml
    
    # Deploy API Gateway
    deploy_api_gateway
    
    # Setup custom domain (unless skipped)
    if [ "$SKIP_DOMAIN" = false ]; then
        setup_custom_domain
    else
        print_warning "Skipping custom domain setup"
    fi
    
    # Test endpoints (unless skipped)
    if [ "$SKIP_TESTS" = false ]; then
        test_endpoints
    else
        print_warning "Skipping endpoint tests"
    fi
    
    print_success "🎉 API Gateway deployment completed successfully!"
    echo ""
    echo "📋 Summary:"
    echo "  API Gateway URL: https://$DOMAIN_NAME"
    echo "  Auth Service: https://$DOMAIN_NAME/auth/*"
    echo "  Vehicle Service: https://$DOMAIN_NAME/vehicle/*"
    echo "  Health Check: https://$DOMAIN_NAME/health"
    echo "  Documentation: https://$DOMAIN_NAME/docs"
    echo ""
    echo "🔧 Next Steps:"
    echo "  1. Update your frontend to use the new API Gateway URL"
    echo "  2. Test all endpoints thoroughly"
    echo "  3. Monitor the API Gateway metrics in AWS Console"
    echo "  4. Set up CloudWatch alarms for monitoring"
}

# Run main function
main "$@" 