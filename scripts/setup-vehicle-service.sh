#!/bin/bash

# Parklense Vehicle Service Deployment Setup Script
# This script helps set up the vehicle service deployment configuration

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to validate AWS credentials
validate_aws_credentials() {
    print_status "Validating AWS credentials..."
    
    if ! aws sts get-caller-identity >/dev/null 2>&1; then
        print_error "AWS credentials not configured or invalid"
        print_status "Please run: aws configure"
        exit 1
    fi
    
    print_success "AWS credentials validated"
}

# Function to validate EKS cluster access
validate_eks_access() {
    print_status "Validating EKS cluster access..."
    
    if ! kubectl cluster-info >/dev/null 2>&1; then
        print_error "Cannot access Kubernetes cluster"
        print_status "Please ensure kubectl is configured for your EKS cluster"
        exit 1
    fi
    
    print_success "EKS cluster access validated"
}

# Function to create ECR repository
create_ecr_repository() {
    local repo_name="$1"
    local region="$2"
    
    print_status "Creating ECR repository: $repo_name"
    
    if aws ecr describe-repositories --repository-names "$repo_name" --region "$region" >/dev/null 2>&1; then
        print_warning "ECR repository $repo_name already exists"
    else
        aws ecr create-repository \
            --repository-name "$repo_name" \
            --region "$region" \
            --image-scanning-configuration scanOnPush=true \
            --encryption-configuration encryptionType=AES256
        
        print_success "ECR repository $repo_name created"
    fi
}

# Function to create EBS volumes
create_ebs_volumes() {
    local environment="$1"
    local region="$2"
    
    print_status "Creating EBS volumes for $environment environment..."
    
    # Get availability zones
    local azs=$(aws ec2 describe-availability-zones --region "$region" --query 'AvailabilityZones[0:3].ZoneName' --output text)
    local az1=$(echo "$azs" | cut -d' ' -f1)
    
    # Create volumes for vehicle service
    local vehicle_media_volume_id=$(aws ec2 create-volume \
        --size 20 \
        --availability-zone "$az1" \
        --volume-type gp3 \
        --tag-specifications "ResourceType=volume,Tags=[{Key=Name,Value=vehicle-media-$environment-pv},{Key=Environment,Value=$environment},{Key=Service,Value=vehicle}]" \
        --region "$region" \
        --query 'VolumeId' \
        --output text)
    
    local vehicle_static_volume_id=$(aws ec2 create-volume \
        --size 10 \
        --availability-zone "$az1" \
        --volume-type gp3 \
        --tag-specifications "ResourceType=volume,Tags=[{Key=Name,Value=vehicle-static-$environment-pv},{Key=Environment,Value=$environment},{Key=Service,Value=vehicle}]" \
        --region "$region" \
        --query 'VolumeId' \
        --output text)
    
    print_success "EBS volumes created:"
    echo "  Vehicle Media: $vehicle_media_volume_id"
    echo "  Vehicle Static: $vehicle_static_volume_id"
    
    # Update PV configurations
    update_pv_configurations "$environment" "$vehicle_media_volume_id" "$vehicle_static_volume_id"
}

# Function to update PV configurations
update_pv_configurations() {
    local environment="$1"
    local media_volume_id="$2"
    local static_volume_id="$3"
    
    print_status "Updating PV configurations for $environment environment..."
    
    local pv_file="k8s/overlays/$environment/storage/pv.yaml"
    
    if [ -f "$pv_file" ]; then
        # Update vehicle media volume ID
        sed -i.bak "s/REPLACE_WITH_ACTUAL_${environment^^}_VEHICLE_MEDIA_VOLUME_ID/$media_volume_id/g" "$pv_file"
        
        # Update vehicle static volume ID
        sed -i.bak "s/REPLACE_WITH_ACTUAL_${environment^^}_VEHICLE_STATIC_VOLUME_ID/$static_volume_id/g" "$pv_file"
        
        print_success "PV configurations updated in $pv_file"
    else
        print_warning "PV file not found: $pv_file"
    fi
}

# Function to create SSL certificate
create_ssl_certificate() {
    local domain="$1"
    local region="$2"
    
    print_status "Creating SSL certificate for $domain..."
    
    # Check if certificate already exists
    local cert_arn=$(aws acm list-certificates --region "$region" --query "CertificateSummaryList[?DomainName=='$domain'].CertificateArn" --output text)
    
    if [ -n "$cert_arn" ] && [ "$cert_arn" != "None" ]; then
        print_warning "SSL certificate for $domain already exists: $cert_arn"
        return
    fi
    
    # Create certificate
    local cert_arn=$(aws acm request-certificate \
        --domain-name "$domain" \
        --validation-method DNS \
        --region "$region" \
        --query 'CertificateArn' \
        --output text)
    
    print_success "SSL certificate created: $cert_arn"
    print_warning "Please validate the certificate by adding the required DNS records"
}

# Function to create secrets
create_secrets() {
    local environment="$1"
    local region="$2"
    
    print_status "Creating secrets for $environment environment..."
    
    # Create vehicle service secrets
    local vehicle_secrets_name="parklense-vehicle-$environment-secrets"
    
    if aws secretsmanager describe-secret --secret-id "$vehicle_secrets_name" --region "$region" >/dev/null 2>&1; then
        print_warning "Secret $vehicle_secrets_name already exists"
    else
        # Create a template secrets file
        cat > /tmp/vehicle-secrets.json << EOF
{
  "database-url": "postgresql://vehicle_user:vehicle_password@vehicle-db-$environment.region.rds.amazonaws.com:5432/vehicle_database",
  "redis-url": "redis://redis-service:6379/0",
  "secret-key": "vehicle_secret_key_for_${environment}_environment_$(openssl rand -hex 32)"
}
EOF
        
        aws secretsmanager create-secret \
            --name "$vehicle_secrets_name" \
            --description "Vehicle service secrets for $environment environment" \
            --secret-string file:///tmp/vehicle-secrets.json \
            --region "$region"
        
        rm -f /tmp/vehicle-secrets.json
        print_success "Secret $vehicle_secrets_name created"
    fi
}

# Function to deploy vehicle service
deploy_vehicle_service() {
    local environment="$1"
    
    print_status "Deploying vehicle service to $environment environment..."
    
    # Apply the deployment
    kubectl apply -k "k8s/overlays/$environment"
    
    # Wait for deployment to be ready
    kubectl rollout status deployment/parklense-vehicle-backend -n "$environment-parklense-auth" --timeout=300s
    
    print_success "Vehicle service deployed to $environment environment"
}

# Main function
main() {
    echo "=========================================="
    echo "Parklense Vehicle Service Setup Script"
    echo "=========================================="
    
    # Check prerequisites
    if ! command_exists aws; then
        print_error "AWS CLI not found. Please install it first."
        exit 1
    fi
    
    if ! command_exists kubectl; then
        print_error "kubectl not found. Please install it first."
        exit 1
    fi
    
    # Get environment from user
    echo "Available environments:"
    echo "1. dev"
    echo "2. staging"
    echo "3. prod"
    read -p "Select environment (1-3): " env_choice
    
    case $env_choice in
        1) environment="dev" ;;
        2) environment="staging" ;;
        3) environment="prod" ;;
        *) print_error "Invalid choice"; exit 1 ;;
    esac
    
    # Get AWS region
    read -p "Enter AWS region (default: us-east-1): " region
    region=${region:-us-east-1}
    
    # Validate credentials and access
    validate_aws_credentials
    validate_eks_access
    
    # Create ECR repository
    create_ecr_repository "parklense-vehicle-managment-service" "$region"
    
    # Create EBS volumes
    read -p "Create EBS volumes for $environment environment? (y/n): " create_volumes
    if [[ $create_volumes =~ ^[Yy]$ ]]; then
        create_ebs_volumes "$environment" "$region"
    fi
    
    # Create SSL certificate
    case $environment in
        "dev") domain="vehicle.parklensedev.com" ;;
        "staging") domain="vehicle.parklensedev.com" ;;
        "prod") domain="vehicle.parklense.com" ;;
    esac
    
    read -p "Create SSL certificate for $domain? (y/n): " create_cert
    if [[ $create_cert =~ ^[Yy]$ ]]; then
        create_ssl_certificate "$domain" "$region"
    fi
    
    # Create secrets
    read -p "Create secrets for $environment environment? (y/n): " create_secrets_choice
    if [[ $create_secrets_choice =~ ^[Yy]$ ]]; then
        create_secrets "$environment" "$region"
    fi
    
    # Deploy service
    read -p "Deploy vehicle service to $environment environment? (y/n): " deploy_choice
    if [[ $deploy_choice =~ ^[Yy]$ ]]; then
        deploy_vehicle_service "$environment"
    fi
    
    print_success "Setup completed successfully!"
    echo ""
    echo "Next steps:"
    echo "1. Update the ECR repository URL in your CI/CD pipeline"
    echo "2. Configure the SSL certificate ARN in ingress configurations"
    echo "3. Update the secrets with actual values"
    echo "4. Test the deployment"
}

# Run main function
main "$@" 