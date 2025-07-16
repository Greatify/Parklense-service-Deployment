#!/bin/bash

# Parklense Auth Service Rollback Script
# Usage: ./scripts/rollback.sh <environment> [revision]

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

# Default values
ENVIRONMENT=""
REVISION=""
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
    echo "Usage: $0 <environment> [revision]"
    echo ""
    echo "Environments:"
    echo "  dev       - Development environment"
    echo "  staging   - Staging environment"
    echo "  prod      - Production environment"
    echo ""
    echo "Revision (optional):"
    echo "  If not specified, rollback to previous revision"
    echo "  Use 'kubectl rollout history deployment/<name>' to see available revisions"
    echo ""
    echo "Examples:"
    echo "  $0 dev                    # Rollback to previous revision"
    echo "  $0 staging 5              # Rollback to revision 5"
    echo "  $0 prod                   # Rollback production to previous revision"
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

# Function to show current deployment status
show_current_status() {
    print_info "Current deployment status in namespace: $NAMESPACE"
    
    echo "Current pods:"
    kubectl get pods -n "$NAMESPACE"
    
    echo ""
    echo "Current deployment status:"
    kubectl get deployments -n "$NAMESPACE"
    
    echo ""
    print_info "Deployment histories:"
    
    # Show rollout history for each deployment
    for deployment in parklense-auth-backend parklense-auth-celery-worker parklense-auth-celery-beat; do
        echo ""
        echo "=== $deployment ==="
        kubectl rollout history deployment/$deployment -n "$NAMESPACE" || echo "No history available"
    done
}

# Function to confirm rollback
confirm_rollback() {
    print_warning "⚠️  You are about to ROLLBACK the deployment ⚠️"
    echo ""
    echo "Environment: $ENVIRONMENT"
    echo "Cluster: $CLUSTER_NAME"
    echo "Namespace: $NAMESPACE"
    
    if [ -n "$REVISION" ]; then
        echo "Target Revision: $REVISION"
    else
        echo "Target: Previous revision"
    fi
    
    echo ""
    
    if [ "$ENVIRONMENT" = "prod" ]; then
        print_error "🚨 PRODUCTION ROLLBACK 🚨"
        read -p "This is a PRODUCTION rollback! Type 'ROLLBACK' to confirm: " confirmation
        if [ "$confirmation" != "ROLLBACK" ]; then
            print_error "Production rollback cancelled"
            exit 1
        fi
    else
        read -p "Are you sure you want to rollback? Type 'yes' to continue: " confirmation
        if [ "$confirmation" != "yes" ]; then
            print_error "Rollback cancelled"
            exit 1
        fi
    fi
    
    print_info "Rollback confirmed"
}

# Function to perform rollback
perform_rollback() {
    print_info "Starting rollback process..."
    
    local deployments=("parklense-auth-backend" "parklense-auth-celery-worker" "parklense-auth-celery-beat")
    
    for deployment in "${deployments[@]}"; do
        print_info "Rolling back $deployment..."
        
        if [ -n "$REVISION" ]; then
            kubectl rollout undo deployment/$deployment -n "$NAMESPACE" --to-revision="$REVISION"
        else
            kubectl rollout undo deployment/$deployment -n "$NAMESPACE"
        fi
        
        print_info "Waiting for $deployment rollback to complete..."
        kubectl rollout status deployment/$deployment -n "$NAMESPACE" --timeout=300s
        
        print_success "$deployment rollback completed"
    done
}

# Function to verify rollback
verify_rollback() {
    print_info "Verifying rollback..."
    
    # Wait a bit for pods to stabilize
    sleep 10
    
    # Check pod status
    echo "Pod status after rollback:"
    kubectl get pods -n "$NAMESPACE"
    
    # Check if all pods are running
    RUNNING_PODS=$(kubectl get pods -n "$NAMESPACE" --field-selector=status.phase=Running --no-headers | wc -l)
    TOTAL_PODS=$(kubectl get pods -n "$NAMESPACE" --no-headers | wc -l)
    
    if [ "$RUNNING_PODS" -eq "$TOTAL_PODS" ]; then
        print_success "All pods are running after rollback ($RUNNING_PODS/$TOTAL_PODS)"
    else
        print_warning "Some pods are not running after rollback ($RUNNING_PODS/$TOTAL_PODS)"
        
        # Show pod details for debugging
        echo ""
        echo "Pods not in Running state:"
        kubectl get pods -n "$NAMESPACE" --field-selector=status.phase!=Running
    fi
    
    # Get ingress URL and test
    INGRESS_URL=$(kubectl get ingress parklense-auth-ingress -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
    
    if [ -n "$INGRESS_URL" ]; then
        print_info "Testing health endpoint after rollback..."
        
        # Try health check multiple times
        for i in {1..5}; do
            if curl -f -s -o /dev/null "https://$INGRESS_URL/api/health/"; then
                print_success "Health check passed (attempt $i)"
                break
            else
                print_warning "Health check failed (attempt $i)"
                if [ $i -eq 5 ]; then
                    print_error "Health check failed after 5 attempts"
                    return 1
                fi
                sleep 10
            fi
        done
    else
        print_warning "Ingress URL not available"
    fi
}

# Function to show post-rollback summary
show_summary() {
    print_info "Rollback Summary"
    echo "=========================="
    echo "Environment: $ENVIRONMENT"
    echo "Namespace: $NAMESPACE"
    echo "Time: $(date)"
    
    if [ -n "$REVISION" ]; then
        echo "Rolled back to revision: $REVISION"
    else
        echo "Rolled back to: Previous revision"
    fi
    
    echo ""
    echo "Current deployment revisions:"
    for deployment in parklense-auth-backend parklense-auth-celery-worker parklense-auth-celery-beat; do
        CURRENT_REVISION=$(kubectl get deployment $deployment -n "$NAMESPACE" -o jsonpath='{.metadata.annotations.deployment\.kubernetes\.io/revision}' 2>/dev/null || echo "Unknown")
        echo "  $deployment: $CURRENT_REVISION"
    done
    
    echo ""
    print_success "Rollback completed successfully! ✅"
    
    if [ "$ENVIRONMENT" = "prod" ]; then
        print_warning "📢 PRODUCTION ROLLBACK COMPLETED - Please notify stakeholders"
    fi
}

# Main execution
main() {
    # Parse arguments
    if [ $# -lt 1 ] || [ $# -gt 2 ]; then
        print_error "Invalid number of arguments"
        show_usage
        exit 1
    fi
    
    ENVIRONMENT=$1
    REVISION=$2
    
    # Validate environment
    validate_environment
    
    # Show rollback information
    echo "=================================================="
    echo "Parklense Auth Service Rollback"
    echo "=================================================="
    echo "Environment: $ENVIRONMENT"
    echo "Cluster: $CLUSTER_NAME"
    echo "Namespace: $NAMESPACE"
    
    if [ -n "$REVISION" ]; then
        echo "Target Revision: $REVISION"
    else
        echo "Target: Previous revision"
    fi
    
    echo "=================================================="
    echo ""
    
    # Run rollback steps
    check_prerequisites
    connect_to_cluster
    show_current_status
    confirm_rollback
    perform_rollback
    
    if verify_rollback; then
        show_summary
    else
        print_error "Rollback verification failed - please check manually"
        exit 1
    fi
}

# Run main function
main "$@" 