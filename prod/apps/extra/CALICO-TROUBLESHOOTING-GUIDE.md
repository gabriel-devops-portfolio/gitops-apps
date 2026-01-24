# Calico Policy-Only Troubleshooting Guide

## Quick Diagnostics

### 🔍 **Health Check Commands**

```bash
# Overall cluster status
kubectl get nodes
kubectl get pods --all-namespaces | grep -E "(tigera|calico)"

# Calico-specific status
kubectl get installation default -o yaml
kubectl get felixconfiguration default -o yaml
kubectl get networkpolicies --all-namespaces
```

### 📊 **Validation Script**

```bash
# Run comprehensive validation
chmod +x validate-calico-deployment.sh
./validate-calico-deployment.sh

# Quick validation (skip policy tests)
./validate-calico-deployment.sh --skip-policy-test

# Generate detailed report
./validate-calico-deployment.sh --report
```

## Common Issues and Solutions

### 1. 🚫 **Tigera Operator Not Starting**

**Symptoms:**

- Operator pod in CrashLoopBackOff
- Installation resource not created
- No calico-system namespace

**Diagnosis:**

```bash
# Check operator pod status
kubectl get pods -n tigera-operator
kubectl describe pod -n tigera-operator -l name=tigera-operator

# Check operator logs
kubectl logs -n tigera-operator deployment/tigera-operator

# Check RBAC permissions
kubectl auth can-i "*" "*" --as=system:serviceaccount:tigera-operator:tigera-operator
```

**Solutions:**

```bash
# Restart operator
kubectl rollout restart deployment/tigera-operator -n tigera-operator

# Check and fix RBAC
kubectl apply -f calico-policy-only.yaml

# Verify cluster admin permissions
kubectl auth can-i "*" "*" --all-namespaces
```

---

### 2. 🔌 **Felix Pods Not Running**

**Symptoms:**

- Felix pods in Pending/CrashLoopBackOff
- Network policies not enforced
- Missing calico-system namespace

**Diagnosis:**

```bash
# Check Felix pod status
kubectl get pods -n calico-system -l k8s-app=calico-felix

# Check Felix logs
kubectl logs -n calico-system ds/calico-felix

# Check node resources
kubectl describe nodes
kubectl top nodes
```

**Solutions:**

```bash
# Check node selector and tolerations
kubectl get installation default -o yaml | grep -A10 nodeSelector

# Verify node labels
kubectl get nodes --show-labels | grep kubernetes.io/os

# Check resource constraints
kubectl describe pod -n calico-system -l k8s-app=calico-felix

# Restart Felix daemonset
kubectl rollout restart daemonset/calico-felix -n calico-system
```

---

### 3. 🌐 **Network Policies Not Working**

**Symptoms:**

- Traffic not blocked when it should be
- Policies applied but no effect
- Connectivity issues

**Diagnosis:**

```bash
# Check policy syntax and application
kubectl describe networkpolicy <policy-name> -n <namespace>

# Verify pod labels match selectors
kubectl get pods --show-labels -n <namespace>

# Check Felix configuration
kubectl get felixconfiguration default -o yaml

# Test connectivity
kubectl exec <source-pod> -- nc -zv <target-ip> <port>
```

**Solutions:**

```bash
# Verify policy selectors match pod labels
kubectl get pods --show-labels -n <namespace>
kubectl describe networkpolicy <policy-name> -n <namespace>

# Check for conflicting policies
kubectl get networkpolicies -n <namespace> -o yaml

# Enable Felix debug logging
kubectl patch felixconfigurationdefault --type merge -p '{"spec":{"logSeverityScreen":"Debug"}}'

# Test with simple allow-all policy
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-all-test
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

---

### 4. 🔍 **DNS Resolution Issues**

**Symptoms:**

- Pods can't resolve DNS names
- `nslookup` or `dig` commands fail
- Service discovery not working

**Diagnosis:**

```bash
# Test DNS resolution
kubectl run dns-test --image=alpine --rm -it -- nslookup kubernetes.default.svc.cluster.local

# Check CoreDNS status
kubectl get pods -n kube-system -l k8s-app=kube-dns

# Check DNS network policy
kubectl get networkpolicy -A | grep dns
```

**Solutions:**

```bash
# Apply DNS allow policy
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns
  namespace: <namespace>
spec:
  podSelector: {}
  policyTypes:
  - Egress
  egress:
  - to: []
    ports:
    - protocol: UDP
      port: 53
    - protocol: TCP
      port: 53
EOF

# Check CoreDNS configuration
kubectl get configmap coredns -n kube-system -o yaml

# Restart CoreDNS if needed
kubectl rollout restart deployment/coredns -n kube-system
```

---

### 5. 🔧 **CNI Configuration Issues**

**Symptoms:**

- Pods stuck in ContainerCreating
- IP allocation failures
- CNI plugin errors

**Diagnosis:**

```bash
# Check Installation CNI configuration
kubectl get installation default -o jsonpath='{.spec.cni}'

# Verify AWS VPC CNI is running
kubectl get daemonset aws-node -n kube-system

# Check CNI logs
kubectl logs -n kube-system ds/aws-node

# Check pod events
kubectl describe pod <stuck-pod>
```

**Solutions:**

```bash
# Verify CNI type is set correctly
kubectl patch installation default --type merge -p '{"spec":{"cni":{"type":"AmazonVPC"}}}'

# Restart AWS VPC CNI
kubectl rollout restart daemonset/aws-node -n kube-system

# Check node IP allocation
kubectl describe node <node-name> | grep -A10 "Addresses"

# Verify ENI limits
aws ec2 describe-instance-types --instance-types <instance-type> --query 'InstanceTypes[0].NetworkInfo'
```

---

### 6. 📈 **Metrics and Monitoring Issues**

**Symptoms:**

- No Calico metrics in Prometheus
- Felix metrics endpoint not accessible
- ServiceMonitor not working

**Diagnosis:**

```bash
# Check Felix metrics configuration
kubectl get felixconfiguration default -o jsonpath='{.spec.prometheusMetricsEnabled}'

# Test metrics endpoint
kubectl port-forward -n calico-system ds/calico-felix 9091:9091
curl http://localhost:9091/metrics

# Check ServiceMonitor
kubectl get servicemonitor -A | grep calico
```

**Solutions:**

```bash
# Enable metrics in Felix
kubectl patch felixconfiguration default --type merge -p '{"spec":{"prometheusMetricsEnabled":true}}'

# Apply ServiceMonitor
kubectl apply -f calico-policy-only.yaml

# Check Prometheus configuration
kubectl get prometheus -A -o yaml | grep -A5 serviceMonitorSelector

# Verify network policy allows metrics scraping
kubectl get networkpolicy -n calico-system
```

---

### 7. 🔄 **Installation Resource Issues**

**Symptoms:**

- Installation resource in failed state
- Components not deploying
- Operator logs show errors

**Diagnosis:**

```bash
# Check Installation status
kubectl get installation default -o yaml

# Check Installation conditions
kubectl get installation default -o jsonpath='{.status.conditions}'

# Check operator logs
kubectl logs -n tigera-operator deployment/tigera-operator
```

**Solutions:**

```bash
# Delete and recreate Installation
kubectl delete installation default
kubectl apply -f calico-policy-only.yaml

# Check for resource conflicts
kubectl get crd | grep calico
kubectl get crd | grep tigera

# Verify cluster meets requirements
kubectl version --short
kubectl get nodes -o wide
```

## Advanced Troubleshooting

### 🔬 **Deep Dive Diagnostics**

1. **Felix Debugging:**

```bash
# Enable debug logging
kubectl patch felixconfiguration default --type merge -p '{"spec":{"logSeverityScreen":"Debug"}}'

# Check Felix status on specific node
kubectl exec -n calico-system ds/calico-felix -- calico-felix --version

# Get Felix configuration dump
kubectl exec -n calico-system ds/calico-felix -- cat /etc/calico/felix.cfg
```

2. **Network Policy Analysis:**

```bash
# List all policies affecting a pod
kubectl get networkpolicy -A -o yaml | grep -B5 -A20 "podSelector"

# Check policy evaluation order
kubectl describe networkpolicy -A

# Test policy with calicoctl (if available)
calicoctl get networkpolicy -A
calicoctl get globalnetworkpolicy
```

3. **CNI Plugin Debugging:**

```bash
# Check CNI configuration files on nodes
kubectl debug node/<node-name> -it --image=alpine -- chroot /host sh
ls -la /etc/cni/net.d/
cat /etc/cni/net.d/*

# Check CNI binary versions
ls -la /opt/cni/bin/
```

### 🚨 **Emergency Procedures**

1. **Disable All Network Policies (Emergency Access):**

```bash
# Create emergency allow-all policy
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

2. **Rollback Calico Installation:**

```bash
# Remove Calico components
kubectl delete installation default
kubectl delete namespace calico-system

# Keep AWS VPC CNI running
kubectl get daemonset aws-node -n kube-system

# Restart operator to clean state
kubectl rollout restart deployment/tigera-operator -n tigera-operator
```

3. **Complete Reset:**

```bash
# Remove all Calico resources
kubectl delete installation default
kubectl delete felixconfiguration default
kubectl delete apiserver default
kubectl delete namespace tigera-operator
kubectl delete namespace calico-system

# Remove CRDs (CAUTION: This removes all Calico data)
kubectl get crd | grep calico | awk '{print $1}' | xargs kubectl delete crd
kubectl get crd | grep tigera | awk '{print $1}' | xargs kubectl delete crd

# Redeploy from scratch
kubectl apply -f calico-policy-only.yaml
```

## Performance Troubleshooting

### 📊 **Resource Usage Analysis**

```bash
# Check Felix resource usage
kubectl top pods -n calico-system

# Check node resource usage
kubectl top nodes

# Check for resource limits
kubectl describe pod -n calico-system -l k8s-app=calico-felix | grep -A5 -B5 "Limits\|Requests"
```

### ⚡ **Performance Optimization**

```bash
# Optimize Felix configuration for performance
kubectl patch felixconfiguration default --type merge -p '{
  "spec": {
    "reportingInterval": "60s",
    "reportingTTL": "180s",
    "bpfEnabled": false
  }
}'

# Adjust resource limits based on cluster size
kubectl patch installation default --type merge -p '{
  "spec": {
    "componentResources": [
      {
        "componentName": "Node",
        "resourceRequirements": {
          "requests": {"cpu": "100m", "memory": "128Mi"},
          "limits": {"cpu": "1000m", "memory": "1Gi"}
        }
      }
    ]
  }
}'
```

## Monitoring and Alerting

### 📈 **Key Metrics to Monitor**

1. **Felix Health:**

   - `felix_active_local_endpoints`
   - `felix_active_policies`
   - `felix_cluster_num_hosts`

2. **Policy Enforcement:**

   - `felix_iptables_chains`
   - `felix_iptables_rules`
   - `felix_policy_update_time`

3. **Resource Usage:**
   - CPU and memory usage of Felix pods
   - Network policy count per namespace
   - Pod creation/deletion rates

### 🚨 **Recommended Alerts**

```yaml
# Example Prometheus alerts
groups:
  - name: calico
    rules:
      - alert: CalicoFelixDown
        expr: up{job="calico-felix"} == 0
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Calico Felix is down"

      - alert: CalicoHighPolicyCount
        expr: felix_active_policies > 1000
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "High number of active policies"
```

## Support Resources

- **Calico Documentation**: https://docs.tigera.io/calico/latest/
- **Troubleshooting Guide**: https://docs.tigera.io/calico/latest/operations/troubleshoot/
- **Network Policy Recipes**: https://github.com/ahmetb/kubernetes-network-policy-recipes
- **EKS Networking**: https://docs.aws.amazon.com/eks/latest/userguide/pod-networking.html

## Getting Help

1. **Gather Information:**

   ```bash
   # Run validation script with report
   ./validate-calico-deployment.sh --report

   # Collect logs
   kubectl logs -n tigera-operator deployment/tigera-operator > operator.log
   kubectl logs -n calico-system ds/calico-felix > felix.log
   ```

2. **Community Support:**

   - Calico Slack: https://slack.projectcalico.org/
   - GitHub Issues: https://github.com/projectcalico/calico/issues
   - Stack Overflow: Tag with `project-calico`

3. **Enterprise Support:**
   - Tigera Support Portal (for Calico Enterprise)
   - AWS Support (for EKS-related issues)
