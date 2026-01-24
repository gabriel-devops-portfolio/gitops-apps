# Calico Policy-Only Deployment Guide for EKS Production

## Overview

This guide covers the deployment and management of Calico in policy-only mode on Amazon EKS. In this configuration:

- **AWS VPC CNI** handles pod networking and IP allocation
- **Calico** provides NetworkPolicy enforcement and advanced security features
- **Best of both worlds**: AWS-native networking with Kubernetes-native security policies

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    EKS Cluster                              │
│                                                             │
│  ┌─────────────────┐    ┌─────────────────────────────────┐ │
│  │   AWS VPC CNI   │    │        Calico Felix             │ │
│  │                 │    │                                 │ │
│  │ • Pod IPs       │    │ • NetworkPolicy Enforcement     │ │
│  │ • Routing       │    │ • Security Rules                │ │
│  │ • ENI Mgmt      │    │ • Traffic Filtering             │ │
│  └─────────────────┘    └─────────────────────────────────┘ │
│                                                             │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │              Tigera Operator                            │ │
│  │  • Manages Calico Components                           │ │
│  │  • Handles Configuration                               │ │
│  │  • Lifecycle Management                                │ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

## Key Features

### ✅ **Production-Ready Security**

- Default deny-all network policies
- Tier-based security (web → api → database)
- Namespace isolation
- Failsafe rules for system components

### ✅ **Monitoring & Observability**

- Prometheus metrics integration
- Health checks and readiness probes
- Comprehensive logging
- ServiceMonitor for Prometheus Operator

### ✅ **High Availability**

- Pod disruption budgets
- Anti-affinity rules
- Rolling update strategy
- Resource limits and requests

### ✅ **Security Hardening**

- Non-root containers
- Read-only root filesystem
- Dropped capabilities
- Security contexts

## Deployment Steps

### Step 1: Prerequisites

1. **EKS Cluster with AWS VPC CNI**:

   ```bash
   # Verify VPC CNI is installed
   kubectl get daemonset aws-node -n kube-system

   # Check CNI configuration
   kubectl describe configmap aws-node -n kube-system
   ```

2. **Required Permissions**:

   ```bash
   # Verify cluster admin access
   kubectl auth can-i "*" "*" --all-namespaces
   ```

3. **Namespace Labels** (for network policies):
   ```bash
   # Label namespaces for policy targeting
   kubectl label namespace production name=production
   kubectl label namespace staging name=staging
   kubectl label namespace monitoring name=monitoring
   kubectl label namespace argocd name=argocd
   kubectl label namespace velero name=velero
   ```

### Step 2: Deploy Calico Policy-Only

1. **Apply Calico Configuration**:

   ```bash
   # Deploy Calico in policy-only mode
   kubectl apply -f calico-policy-only.yaml

   # Wait for operator to be ready
   kubectl wait --for=condition=available --timeout=300s deployment/tigera-operator -n tigera-operator
   ```

2. **Verify Installation**:

   ```bash
   # Check operator status
   kubectl get pods -n tigera-operator

   # Check Calico installation
   kubectl get installation default -o yaml

   # Verify Calico components
   kubectl get pods -n calico-system
   ```

3. **Check Felix Configuration**:

   ```bash
   # Verify Felix is running on nodes
   kubectl get pods -n calico-system -l k8s-app=calico-felix

   # Check Felix configuration
   kubectl get felixconfiguration default -o yaml
   ```

### Step 3: Apply Network Policies

1. **Deploy Production Network Policies**:

   ```bash
   # Apply comprehensive network policies
   kubectl apply -f network-policies-production.yaml
   ```

2. **Verify Policy Application**:

   ```bash
   # List all network policies
   kubectl get networkpolicies --all-namespaces

   # Check specific policy
   kubectl describe networkpolicy production-namespace-policy -n production
   ```

### Step 4: Validation and Testing

1. **Test Network Connectivity**:

   ```bash
   # Create test pods
   kubectl run test-web --image=nginx --labels="tier=web" -n production
   kubectl run test-api --image=nginx --labels="tier=api" -n production
   kubectl run test-db --image=nginx --labels="tier=database" -n production

   # Test allowed connections (web → api)
   kubectl exec test-web -n production -- curl -m 5 test-api.production.svc.cluster.local

   # Test blocked connections (web → db, should fail)
   kubectl exec test-web -n production -- curl -m 5 test-db.production.svc.cluster.local
   ```

2. **Verify DNS Resolution**:

   ```bash
   # Test DNS from any pod
   kubectl exec test-web -n production -- nslookup kubernetes.default.svc.cluster.local
   ```

3. **Check Calico Status**:

   ```bash
   # Use calicoctl (if installed)
   calicoctl get nodes
   calicoctl get networkpolicies

   # Or check via kubectl
   kubectl get nodes -o wide
   kubectl get networkpolicies --all-namespaces
   ```

## Network Policy Patterns

### 1. **Default Deny Pattern**

```yaml
# Deny all traffic by default
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: name:default-deny-all
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress
```

### 2. **Allow DNS Pattern**

```yaml
# Allow DNS resolution
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns
spec:
  podSelector: {}
  policyTypes:
    - Egress
  egress:
    - to: []
      ports:
        - protocol: UDP
          port: 53
```

### 3. **Tier-Based Communication**

```yaml
# Web tier can access API tier
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: web-to-api
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
          port: 8080
```

### 4. **Namespace Isolation**

```yaml
# Only allow traffic within namespace
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: namespace-isolation
spec:
  podSelector: {}
  policyTypes:
    - Ingress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              name: production
```

## Monitoring and Troubleshooting

### Monitoring Setup

1. **Prometheus Metrics**:

   ```bash
   # Check Felix metrics endpoint
   kubectl port-forward -n calico-system ds/calico-felix 9091:9091
   curl http://localhost:9091/metrics
   ```

2. **ServiceMonitor Configuration**:
   ```yaml
   # Already included in calico-policy-only.yaml
   apiVersion: monitoring.coreos.com/v1
   kind: ServiceMonitor
   metadata:
     name: calico-felix
   spec:
     selector:
       matchLabels:
         k8s-app: calico-felix
   ```

### Troubleshooting Commands

1. **Check Calico Status**:

   ```bash
   # Operator logs
   kubectl logs -n tigera-operator deployment/tigera-operator

   # Felix logs
   kubectl logs -n calico-system ds/calico-felix

   # Installation status
   kubectl get installation default -o yaml
   ```

2. **Network Policy Debugging**:

   ```bash
   # Check policy application
   kubectl describe networkpolicy <policy-name> -n <namespace>

   # Check pod labels
   kubectl get pods --show-labels -n <namespace>

   # Test connectivity
   kubectl exec <pod> -- nc -zv <target-ip> <port>
   ```

3. **Felix Debugging**:

   ```bash
   # Enable debug logging
   kubectl patch felixconfiguration default --type merge -p '{"spec":{"logSeverityScreen":"Debug"}}'

   # Check Felix status on node
   kubectl exec -n calico-system ds/calico-felix -- calico-felix --version
   ```

### Common Issues and Solutions

1. **Pods Can't Resolve DNS**:

   ```bash
   # Check DNS policy is applied
   kubectl get networkpolicy allow-dns-access -n <namespace>

   # Verify CoreDNS is running
   kubectl get pods -n kube-system -l k8s-app=kube-dns
   ```

2. **Network Policies Not Working**:

   ```bash
   # Check Calico Felix is running
   kubectl get pods -n calico-system -l k8s-app=calico-felix

   # Verify policy syntax
   kubectl describe networkpolicy <policy-name>

   # Check pod labels match selectors
   kubectl get pods --show-labels
   ```

3. **Operator Issues**:

   ```bash
   # Check operator status
   kubectl get pods -n tigera-operator

   # Check installation resource
   kubectl get installation default -o yaml

   # Restart operator if needed
   kubectl rollout restart deployment/tigera-operator -n tigera-operator
   ```

## Security Best Practices

### 1. **Default Deny Strategy**

- Start with deny-all policies
- Explicitly allow required traffic
- Use least privilege principle

### 2. **Namespace Segmentation**

- Isolate environments (prod/staging/dev)
- Separate system namespaces
- Use namespace selectors in policies

### 3. **Application Tiers**

- Implement tier-based security (web/api/db)
- Restrict database access to API tier only
- Allow monitoring access where needed

### 4. **Regular Auditing**

```bash
# Audit network policies
kubectl get networkpolicies --all-namespaces -o wide

# Check for pods without policies
kubectl get pods --all-namespaces --show-labels | grep -v "networkpolicy"

# Review policy effectiveness
kubectl describe networkpolicy <policy-name>
```

## Performance Considerations

### 1. **Resource Allocation**

- Set appropriate CPU/memory limits
- Monitor Felix resource usage
- Scale based on cluster size

### 2. **Policy Optimization**

- Minimize policy complexity
- Use efficient selectors
- Avoid overlapping policies

### 3. **Monitoring**

- Track policy evaluation metrics
- Monitor Felix performance
- Set up alerting for issues

## Compliance and Governance

### 1. **Policy as Code**

- Store policies in Git
- Use GitOps for deployment
- Implement policy review process

### 2. **Documentation**

- Document policy intent
- Maintain network diagrams
- Keep troubleshooting guides updated

### 3. **Testing**

- Automated policy testing
- Regular connectivity validation
- Disaster recovery testing

## Migration and Rollback

### 1. **Gradual Rollout**

```bash
# Start with permissive policies
# Gradually tighten restrictions
# Monitor application behavior
```

### 2. **Rollback Procedure**

```bash
# Remove restrictive policies
kubectl delete networkpolicy <policy-name> -n <namespace>

# Restore previous configuration
kubectl apply -f previous-policies.yaml
```

### 3. **Emergency Access**

```bash
# Temporary allow-all policy
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: emergency-allow-all
  namespace: <namespace>
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - {}
  egress:
  - {}
EOF
```

## Support and Resources

- **Calico Documentation**: https://docs.tigera.io/calico/latest/
- **Network Policy Recipes**: https://github.com/ahmetb/kubernetes-network-policy-recipes
- **EKS Best Practices**: https://aws.github.io/aws-eks-best-practices/
- **Troubleshooting Guide**: https://docs.tigera.io/calico/latest/operations/troubleshoot/

## Conclusion

This Calico policy-only deployment provides:

- ✅ Production-grade network security
- ✅ AWS VPC CNI compatibility
- ✅ Comprehensive monitoring
- ✅ Operational best practices
- ✅ Scalable policy management

The configuration is designed for enterprise production environments with security, reliability, and maintainability as primary concerns.
