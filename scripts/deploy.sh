#!/bin/bash

# Parklense Auth Service Deployment Script
# Usage: ./scripts/deploy.sh <environment> <image_tag>

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
KUBECONFIG_FILE="${HOME}/.kube/config"

# Default values
ENVIRONMENT=""
IMAGE_TAG=""
CLUSTER_NAME=""
AWS_REGION="ap-south-1"
NAMESPACE=""

# Function to print colored output
print_info() {
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

# Function to show usage
show_usage() {
    echo "Usage: $0 <environment> <image_tag>"
    echo ""
    echo "Environments:"
    echo "  dev       - Development environment"
    echo "  staging   - Staging environment"
    echo "  prod      - Production environment"
    echo ""
    echo "Examples:"
    echo "  $0 dev latest"
      echo "  $0 staging 399600302704.dkr.ecr.ap-south-1.amazonaws.com/parklense-auth-service:main-abc123"
  echo "  $0 prod 399600302704.dkr.ecr.ap-south-1.amazonaws.com/parklense-auth-service:v1.2.3"
    echo ""
}

# Function to validate environment
validate_environment() {
    case $ENVIRONMENT in
        "dev")
            CLUSTER_NAME="dev-cluster"
            NAMESPACE="dev-parklense"
            ;;
        "staging")
            CLUSTER_NAME="staging-cluster"
            NAMESPACE="staging-parklense-auth"
            ;;
        "prod")
            CLUSTER_NAME="prod-cluster"
            NAMESPACE="prod-parklense-auth"
            ;;
        *)
            print_error "Invalid environment: $ENVIRONMENT"
            show_usage
            exit 1
            ;;
    esac
}

# Function to check prerequisites
check_prerequisites() {
    print_info "Checking prerequisites..."
    
    # Check if kubectl is installed
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed or not in PATH"
        exit 1
    fi
    
    # Check if aws cli is installed
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed or not in PATH"
        exit 1
    fi
    
    # Check if yq is installed
    if ! command -v yq &> /dev/null; then
        print_error "yq is not installed or not in PATH"
        print_info "Install yq: sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 && sudo chmod +x /usr/local/bin/yq"
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS credentials not configured or invalid"
        exit 1
    fi
    
    print_success "All prerequisites met"
}

# Function to connect to Kubernetes cluster
connect_to_cluster() {
    print_info "Connecting to Kubernetes cluster: $CLUSTER_NAME"
    
    # Update kubeconfig
    aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$AWS_REGION"
    
    # Test connection
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Failed to connect to Kubernetes cluster"
        exit 1
    fi
    
    print_success "Connected to cluster: $CLUSTER_NAME"
}

# Function to check current deployment status
check_current_status() {
    print_info "Checking current deployment status in namespace: $NAMESPACE"
    
    echo "Current pods:"
    kubectl get pods -n "$NAMESPACE" 2>/dev/null || echo "Namespace does not exist yet"
    
    echo ""
    echo "Current services:"
    kubectl get services -n "$NAMESPACE" 2>/dev/null || echo "No services found"
    
    echo ""
    echo "Current ingress:"
    kubectl get ingress -n "$NAMESPACE" 2>/dev/null || echo "No ingress found"
}

# Function to update image tags
update_image_tags() {
    print_info "Updating image tags to: $IMAGE_TAG"
    
    cd "$PROJECT_ROOT"
    
    # Update deployment files
    yq -i ".spec.template.spec.containers[0].image = \"$IMAGE_TAG\"" k8s/base/deployment/auth-backend-deployment.yaml
    yq -i ".spec.template.spec.containers[0].image = \"$IMAGE_TAG\"" k8s/base/deployment/celery-worker-deployment.yaml
    yq -i ".spec.template.spec.containers[0].image = \"$IMAGE_TAG\"" k8s/base/deployment/celery-beat-deployment.yaml
    
    print_success "Image tags updated"
}

# Function to deploy
deploy() {
    print_info "Starting deployment to $ENVIRONMENT environment..."
    
    cd "$PROJECT_ROOT"
    
    # Apply the deployment
    kubectl apply -k "k8s/overlays/$ENVIRONMENT"
    
    print_info "Waiting for deployments to complete..."
    
    # Wait for rollout to complete
    kubectl rollout status deployment/parklense-auth-backend -n "$NAMESPACE" --timeout=300s
    kubectl rollout status deployment/parklense-auth-celery-worker -n "$NAMESPACE" --timeout=300s
    kubectl rollout status deployment/parklense-auth-celery-beat -n "$NAMESPACE" --timeout=300s
    
    print_success "Deployment completed successfully"
}

# Function to verify deployment
verify_deployment() {
    print_info "Verifying deployment..."
    
    # Check pod status
    echo "Pod status:"
    kubectl get pods -n "$NAMESPACE"
    
    # Check if all pods are running
    RUNNING_PODS=$(kubectl get pods -n "$NAMESPACE" --field-selector=status.phase=Running --no-headers | wc -l)
    TOTAL_PODS=$(kubectl get pods -n "$NAMESPACE" --no-headers | wc -l)
    
    if [ "$RUNNING_PODS" -eq "$TOTAL_PODS" ]; then
        print_success "All pods are running ($RUNNING_PODS/$TOTAL_PODS)"
    else
        print_warning "Some pods are not running ($RUNNING_PODS/$TOTAL_PODS)"
    fi
    
    # Get ingress URL
    INGRESS_URL=$(kubectl get ingress parklense-auth-ingress -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
    
    if [ -n "$INGRESS_URL" ]; then
        print_info "Ingress URL: https://$INGRESS_URL"
        
        # Try health check
        print_info "Testing health endpoint..."
        if curl -f -s -o /dev/null "https://$INGRESS_URL/api/health/"; then
            print_success "Health check passed"
        else
            print_warning "Health check failed - service might still be starting"
        fi
    else
        print_warning "Ingress URL not available yet"
    fi
}

# Function to confirm production deployment
confirm_production() {
    if [ "$ENVIRONMENT" = "prod" ]; then
        print_warning "⚠️  You are about to deploy to PRODUCTION ⚠️"
        echo ""
        echo "Environment: $ENVIRONMENT"
        echo "Image: $IMAGE_TAG"
        echo "Cluster: $CLUSTER_NAME"
        echo "Namespace: $NAMESPACE"
        echo ""
        
        read -p "Are you sure you want to proceed? Type 'CONFIRM' to continue: " confirmation
        
        if [ "$confirmation" != "CONFIRM" ]; then
            print_error "Production deployment cancelled"
            exit 1
        fi
        
        print_info "Production deployment confirmed"
    fi
}

# Main execution
main() {
    # Parse arguments
    if [ $# -ne 2 ]; then
        print_error "Invalid number of arguments"
        show_usage
        exit 1
    fi
    
    ENVIRONMENT=$1
    IMAGE_TAG=$2
    
    # Validate environment
    validate_environment
    
    # Show deployment information
    echo "=================================================="
    echo "Parklense Auth Service Deployment"
    echo "=================================================="
    echo "Environment: $ENVIRONMENT"
    echo "Image: $IMAGE_TAG"
    echo "Cluster: $CLUSTER_NAME"
    echo "Namespace: $NAMESPACE"
    echo "=================================================="
    echo ""
    
    # Confirm production deployment
    confirm_production
    
    # Run deployment steps
    check_prerequisites
    connect_to_cluster
    check_current_status
    update_image_tags
    deploy
    verify_deployment
    
    print_success "Deployment completed successfully! 🚀"
}

# Run main function
main "$@" 