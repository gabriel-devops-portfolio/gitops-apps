#!/bin/bash

# Calico Policy-Only Deployment Validation Script
# This script validates the Calico installation and network policy enforcement

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_debug() {
    echo -e "${BLUE}[DEBUG]${NC} $1"
}

# Check if required tools are installed
check_prerequisites() {
    log_info "Checking prerequisites..."

    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed or not in PATH"
        exit 1
    fi

    if ! command -v jq &> /dev/null; then
        log_warn "jq is not installed - some checks will be limited"
    fi

    # Check cluster connectivity
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi

    log_info "Prerequisites check passed"
}

# Verify Tigera Operator installation
verify_operator() {
    log_info "Verifying Tigera Operator installation..."

    # Check if namespace exists
    if ! kubectl get namespace tigera-operator &> /dev/null; then
        log_error "tigera-operator namespace not found"
        return 1
    fi

    # Check operator deployment
    if ! kubectl get deployment tigera-operator -n tigera-operator &> /dev/null; then
        log_error "tigera-operator deployment not found"
        return 1
    fi

    # Check deployment status
    READY_REPLICAS=$(kubectl get deployment tigera-operator -n tigera-operator -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    DESIRED_REPLICAS=$(kubectl get deployment tigera-operator -n tigera-operator -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "1")

    if [ "$READY_REPLICAS" != "$DESIRED_REPLICAS" ]; then
        log_error "Tigera operator is not ready. Ready: $READY_REPLICAS, Desired: $DESIRED_REPLICAS"
        kubectl get pods -n tigera-operator
        return 1
    fi

    log_info "Tigera Operator is running successfully"
}

# Verify Calico installation
verify_calico_installation() {
    log_info "Verifying Calico installation..."

    # Check Installation resource
    if ! kubectl get installation default &> /dev/null; then
        log_error "Calico Installation resource not found"
        return 1
    fi

    # Check installation status
    INSTALL_STATUS=$(kubectl get installation default -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "Unknown")

    if [ "$INSTALL_STATUS" != "True" ]; then
        log_error "Calico installation is not ready. Status: $INSTALL_STATUS"
        kubectl get installation default -o yaml
        return 1
    fi

    # Check if calico-system namespace exists
    if ! kubectl get namespace calico-system &> /dev/null; then
        log_error "calico-system namespace not found"
        return 1
    fi

    # Check Calico pods
    CALICO_PODS=$(kubectl get pods -n calico-system --no-headers 2>/dev/null | wc -l)
    if [ "$CALICO_PODS" -eq 0 ]; then
        log_error "No Calico pods found in calico-system namespace"
        return 1
    fi

    # Check Felix pods (should be running on each node)
    NODE_COUNT=$(kubectl get nodes --no-headers | wc -l)
    FELIX_PODS=$(kubectl get pods -n calico-system -l k8s-app=calico-felix --no-headers 2>/dev/null | grep -c "Running" || echo "0")

    if [ "$FELIX_PODS" -ne "$NODE_COUNT" ]; then
        log_warn "Felix pod count ($FELIX_PODS) doesn't match node count ($NODE_COUNT)"
        kubectl get pods -n calico-system -l k8s-app=calico-felix
    else
        log_info "Felix pods are running on all nodes ($FELIX_PODS/$NODE_COUNT)"
    fi

    log_info "Calico installation verified successfully"
}

# Verify CNI configuration
verify_cni_configuration() {
    log_info "Verifying CNI configuration..."

    # Check Installation CNI type
CNI_TYPE=$(kubectl get installation default -o jsonpath='{.spec.cni.type}' 2>/dev/null || echo "Unknown")

    if [ "$CNI_TYPE" != "AmazonVPC" ]; then
        log_error "CNI type is not set to AmazonVPC. Current: $CNI_TYPE"
        return 1
    fi

    # Check AWS VPC CNI is still running
    if ! kubectl get daemonset aws-node -n kube-system &> /dev/null; then
        log_error "AWS VPC CNI daemonset not found"
        return 1
    fi

    AWS_NODE_READY=$(kubectl get daemonset aws-node -n kube-system -o jsonpath='{.status.numberReady}' 2>/dev/null || echo "0")
    AWS_NODE_DESIRED=$(kubectl get daemonset aws-node -n kube-system -o jsonpath='{.status.desiredNumberScheduled}' 2>/dev/null || echo "1")

    if [ "$AWS_NODE_READY" != "$AWS_NODE_DESIRED" ]; then
        log_error "AWS VPC CNI is not ready on all nodes. Ready: $AWS_NODE_READY, Desired: $AWS_NODE_DESIRED"
        return 1
    fi

    log_info "CNI configuration verified - using AWS VPC CNI with Calico policy enforcement"
}

# Verify Felix configuration
verify_felix_configuration() {
    log_info "Verifying Felix configuration..."

    # Check FelixConfiguration resource
    if ! kubectl get felixconfiguration default &> /dev/null; then
        log_error "FelixConfiguration resource not found"
        return 1
    fi

    # Check if metrics are enabled
    METRICS_ENABLED=$(kubectl get felixconfiguration default -o jsonpath='{.spec.prometheusMetricsEnabled}' 2>/dev/null || echo "false")

    if [ "$METRICS_ENABLED" != "true" ]; then
        log_warn "Prometheus metrics are not enabled in Felix configuration"
    else
        log_info "Prometheus metrics are enabled"
    fi

    # Check health configuration
    HEALTH_ENABLED=$(kubectl get felixconfiguration default -o jsonpath='{.spec.healthEnabled}' 2>/dev/null || echo "false")

    if [ "$HEALTH_ENABLED" == "true" ]; then
        log_info "Felix health checks are enabled"
    else
        log_warn "Felix health checks are not explicitly enabled"
    fi

    log_info "Felix configuration verified"
}

# Test network policy enforcement
test_network_policies() {
    log_info "Testing network policy enforcement..."

    # Create test namespace
    TEST_NAMESPACE="calico-test-$(date +%s)"
    log_debug "Creating test namespace: $TEST_NAMESPACE"

    kubectl create namespace "$TEST_NAMESPACE" || {
        log_error "Failed to create test namespace"
        return 1
    }

    # Cleanup function
    cleanup_test() {
        log_debug "Cleaning up test resources..."
        kubectl delete namespace "$TEST_NAMESPACE" --ignore-not-found=true &> /dev/null || true
    }

    # Set trap for cleanup
    trap cleanup_test EXIT

    # Create test pods
    log_debug "Creating test pods..."

    # Web tier pod
    kubectl run test-web --image=nginx:alpine --labels="tier=web" -n "$TEST_NAMESPACE" --restart=Never || {
        log_error "Failed to create web test pod"
        return 1
    }

    # API tier pod
    kubectl run test-api --image=nginx:alpine --labels="tier=api" -n "$TEST_NAMESPACE" --restart=Never || {
        log_error "Failed to create API test pod"
        return 1
    }

    # Database tier pod
    kubectl run test-db --image=nginx:alpine --labels="tier=database" -n "$TEST_NAMESPACE" --restart=Never || {
        log_error "Failed to create database test pod"
        return 1
    }

    # Wait for pods to be ready
    log_debug "Waiting for test pods to be ready..."
    kubectl wait --for=condition=ready pod --all -n "$TEST_NAMESPACE" --timeout=60s || {
        log_error "Test pods did not become ready in time"
        kubectl get pods -n "$TEST_NAMESPACE"
        return 1
    }

    # Apply default deny policy to test namespace
    log_debug "Applying default deny policy..."
    kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: $TEST_NAMESPACE
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
EOF

    # Test that communication is blocked
    log_debug "Testing that default deny policy blocks communication..."

    # This should fail (timeout after 5 seconds)
    if kubectl exec test-web -n "$TEST_NAMESPACE" -- timeout 5 nc -zv test-api 80 &> /dev/null; then
        log_error "Default deny policy is not working - communication should be blocked"
        return 1
    else
        log_info "✓ Default deny policy is working - communication blocked as expected"
    fi

    # Apply policy to allow web -> api communication
    log_debug "Applying policy to allow web -> api communication..."
    kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-web-to-api
  namespace: $TEST_NAMESPACE
spec:
  podSelector:
   matchLabels:
      tier: api
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          tier: web
    ports:
    - protocol: TCP
      port: 80
EOF

    # Wait a moment for policy to take effect
    sleep 5

    # Test that web -> api communication is now allowed
    log_debug "Testing that web -> api communication is now allowed..."

    if kubectl exec test-web -n "$TEST_NAMESPACE" -- timeout 10 nc -zv test-api 80 &> /dev/null; then
        log_info "✓ Network policy allowing web -> api communication is working"
    else
        log_error "Network policy is not working - web -> api communication should be allowed"
        return 1
    fi

    # Test that web -> database communication is still blocked
    log_debug "Testing that web -> database communication is still blocked..."

    if kubectl exec test-web -n "$TEST_NAMESPACE" -- timeout 5 nc -zv test-db 80 &> /dev/null; then
        log_error "Network policy is not working - web -> database communication should be blocked"
        return 1
    else
        log_info "✓ Network policy is working - web -> database communication blocked as expected"
    fi

    log_info "Network policy enforcement test completed successfully"
}

# Test DNS resolution
test_dns_resolution() {
    log_info "Testing DNS resolution..."

    # Create a simple test pod
    TEST_POD="dns-test-$(date +%s)"

    kubectl run "$TEST_POD" --image=alpine:latest --restart=Never --rm -i --tty=false -- /bin/sh -c "
        nslookup kubernetes.default.svc.cluster.local &&
        nslookup google.com
    " || {
        log_error "DNS resolution test failed"
        return 1
    }

    log_info "✓ DNS resolution is working correctly"
}

# Check metrics availability
check_metrics() {
    log_info "Checking Calico metrics availability..."

    # Check if Felix pods expose metrics
    FELIX_PODS=$(kubectl get pods -n calico-system -l k8s-app=calico-felix -o name 2>/dev/null)

    if [ -z "$FELIX_PODS" ]; then
        log_warn "No Felix pods found for metrics check"
        return 1
    fi

    # Test metrics endpoint on first Felix pod
    FIRST_FELIX=$(echo "$FELIX_PODS" | head -n1)

    if kubectl exec -n calico-system "$FIRST_FELIX" -- wget -qO- http://localhost:9091/metrics | head -n5 &> /dev/null; then
        log_info "✓ Felix metrics endpoint is accessible"
    else
        log_warn "Felix metrics endpoint is not accessible"
    fi
}

# Generate summary report
generate_report() {
    log_info "Generating validation report..."

    REPORT_FILE="calico-validation-report-$(date +%Y%m%d-%H%M%S).txt"

    {
        echo "Calico Policy-Only Deployment Validation Report"
        echo "=============================================="
        echo "Date: $(date)"
        echo "Cluster: $(kubectl config current-context)"
        echo ""

        echo "Tigera Operator Status:"
        kubectl get deployment tigera-operator -n tigera-operator -o wide 2>/dev/null || echo "Not found"
        echo ""

        echo "Calico Installation Status:"
        kubectl get installation default -o yaml 2>/dev/null || echo "Not found"
        echo ""

        echo "Calico System Pods:"
        kubectl get pods -n calico-system -o wide 2>/dev/null || echo "Namespace not found"
        echo ""

        echo "Felix Configuration:"
        kubectl get felixconfiguration default -o yaml 2>/dev/null || echo "Not found"
        echo ""

        echo "Network Policies (All Namespaces):"
        kubectl get networkpolicies --all-namespaces -o wide 2>/dev/null || echo "None found"
        echo ""

        echo "Node Status:"
        kubectl get nodes -o wide
        echo ""

        echo "AWS VPC CNI Status:"
        kubectl get daemonset aws-node -n kube-system -o wide 2>/dev/null || echo "Not found"

    } > "$REPORT_FILE"

    log_info "Validation report saved to: $REPORT_FILE"
}

# Main execution function
main() {
    echo "=================================================="
    echo "Calico Policy-Only Deployment Validation"
    echo "=================================================="
    echo ""

    local exit_code=0

    # Run all validation checks
    check_prerequisites || exit_code=1
    verify_operator || exit_code=1
    verify_calico_installation || exit_code=1
    verify_cni_configuration || exit_code=1
    verify_felix_configuration || exit_code=1

    # Optional tests (don't fail on these)
    test_dns_resolution || log_warn "DNS test failed but continuing..."
    check_metrics || log_warn "Metrics check failed but continuing..."

    # Network policy test (can be skipped with --skip-policy-test)
    if [[ "$1" != "--skip-policy-test" ]]; then
        test_network_policies || exit_code=1
    else
        log_info "Skipping network policy test (--skip-policy-test specified)"
    fi

    # Generate report if requested
    if [[ "$1" == "--report" ]] || [[ "$2" == "--report" ]]; then
        generate_report
    fi

    echo ""
    echo "=================================================="
    if [ $exit_code -eq 0 ]; then
        log_info "✅ All validation checks passed successfully!"
        echo "Calico policy-only mode is properly configured and working."
    else
        log_error"❌ Some validation checks failed!"
        echo "Please review the errors above and fix the issues."
    fi
    echo "=================================================="

    exit $exit_code
}

# Help function
show_help() {
    echo "Calico Policy-Only Deployment Validation Script"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --skip-policy-test    Skip the network policy enforcement test"
    echo "  --report             Generate a detailed validation report"
    echo "  --help               Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                           # Run all validation checks"
    echo "  $0 --skip-policy-test        # Skip policy test (faster)"
    echo "  $0 --report                  # Generate detailed report"
    echo "  $0 --skip-policy-test --report  # Skip policy test and generate report"
}

# Parse command line arguments
case "$1" in
    --help|-h)
        show_help
        exit 0
        ;;
    *)
        main "$@"
        ;;
esac
