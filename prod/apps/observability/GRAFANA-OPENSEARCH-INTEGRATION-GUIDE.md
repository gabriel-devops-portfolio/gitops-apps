# Grafana OpenSearch Integration Guide

## 🎯 Overview

This guide covers the integration of OpenSearch (Security Lake data) with Grafana to create a unified observability platform. You'll have a single pane of glass for:

- **📊 Metrics** - Prometheus (infrastructure & application metrics)
- **📝 Logs** - Loki (application logs) + OpenSearch (security logs)
- **🔍 Traces** - Jaeger (distributed tracing)
- **🛡️ Security** - OpenSearch (OCSF-normalized security data from Security Lake)

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Unified Grafana Dashboard                   │
│                                                                 │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ │
│  │ Prometheus  │ │    Loki     │ │   Jaeger    │ │ OpenSearch  │ │
│  │             │ │             │ │             │ │             │ │
│  │ • Metrics   │ │ • App Logs  │ │ • Traces    │ │ • Security  │ │
│  │ • Alerts    │ │ • K8s Logs  │ │ • Spans     │ │ • OCSF Data │ │
│  │ • Rules     │ │ • System    │ │ • Services  │ │ • Findings  │ │
│  └─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘ │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │              Cross-Account Security Access                  │ │
│  │    Workload Account → Security Account (OpenSearch)        │ │
│  └─────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

## 📋 Prerequisites

### 1. **Deployed Components**

- ✅ Grafana (kube-prometheus-stack)
- ✅ OpenSearch in security account
- ✅ Security Lake with OCSF data
- ✅ Cross-account IAM roles

### 2. **Required Information**

```bash
# Get OpenSearch endpoint
aws opensearch describe-domain --domain-name security-logs --region us-east-1

# Get security account ID
aws sts get-caller-identity --query Account --output text
```

## 🚀 Deployment Steps

### Step 1: Deploy Cross-Account IAM Roles

1. **In Security Account** - Deploy the Grafana access role:

   ```bash
   cd terraform-infra/security-account/cross-account-roles
   terraform apply -target=aws_iam_role.grafana_opensearch
   ```

2. **Verify Role Creation**:
   ```bash
   aws iam get-role --role-name GrafanaOpenSearchRole
   ```

### Step 2: Configure Workload Account

1. **Update terraform.tfvars**:

   ```hcl
   # Add my security account ID
   security_account_id = "123456789012"  # Replace with actual ID
   ```

2. **Deploy Grafana Integration**:
   ```bash
   cd terraform-infra/workload-account/environments/production
   terraform apply -target=aws_iam_role.grafana_service_account
   ```

### Step 3: Update Grafana Configuration

1. **Get OpenSearch Endpoint**:

   ```bash
   # In security account
   OPENSEARCH_ENDPOINT=$(aws opensearch describe-domain \
     --domain-name security-logs \
     --query 'DomainStatus.Endpoint' \
     --output text)
   echo "https://$OPENSEARCH_ENDPOINT"
   ```

2. **Update Grafana Data Sources**:

   ```bash
   # Edit the Grafana configuration
   # Replace <DOMAIN-SUFFIX> and <SECURITY-ACCOUNT-ID> in:
   # gitops-apps/prod/apps/observability/apps-kube-prometheus-stack.yaml
   ```

3. **Apply Updated Configuration**:
   ```bash
   # ArgoCD will automatically sync the changes
   # Or manually apply:
   kubectl apply -f gitops-apps/prod/apps/observability/apps-kube-prometheus-stack.yaml
   ```

### Step 4: Verify Integration

1. **Check Grafana Pod Annotations**:

   ```bash
   kubectl describe sa kube-prometheus-stack-grafana -n monitoring
   # Should show: eks.amazonaws.com/role-arn annotation
   ```

2. **Access Grafana**:

   ```bash
   kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
   # Access: http://localhost:3000
   ```

3. **Verify Data Sources**:
   - Go to Configuration → Data Sources
   - Should see: Prometheus, Loki, Jaeger, OpenSearch-SecurityLogs, OpenSearch-AppLogs

## 🔧 Configuration Details

### **OpenSearch Data Source Configuration**

```yaml
# Security Logs Data Source
- name: OpenSearch-SecurityLogs
  type: opensearch
  access: proxy
  url: https://search-security-logs-<DOMAIN-SUFFIX>.us-east-1.es.amazonaws.com
  jsonData:
    timeField: "@timestamp"
    esVersion: "8.0.0"
    sigV4Auth: true
    sigV4Region: us-east-1
    sigV4AssumeRoleArn: "arn:aws:iam::<SECURITY-ACCOUNT-ID>:role/GrafanaOpenSearchRole"
```

### **Key Configuration Parameters**

| Parameter            | Value              | Purpose                       |
| -------------------- | ------------------ | ----------------------------- |
| `timeField`          | `@timestamp`       | OCSF standard timestamp field |
| `esVersion`          | `8.0.0`            | OpenSearch compatibility      |
| `sigV4Auth`          | `true`             | AWS IAM authentication        |
| `sigV4AssumeRoleArn` | Cross-account role | Security account access       |

## 📊 Available Dashboards

### **1. Security Overview Dashboard**

- **Purpose**: High-level security metrics from OCSF data
- **Panels**:
  - Security events over time
  - Top security event types
  - Failed authentication attempts
  - Network anomalies

### **2. Terraform State Access Dashboard**

- **Purpose**: Monitor infrastructure access
- **Panels**:
  - Terraform state access events
  - Access by user
  - Access by source IP

### **3. Custom Dashboard Creation**

Use these OCSF fields for custom dashboards:

```json
{
  "class_name": "API Activity | Network Activity | Authentication",
  "activity_name": "Logon | Create | Delete | Update",
  "severity": "Critical | High | Medium | Low",
  "status": "Success | Failure",
  "actor.user.name": "Username",
  "src_endpoint.ip": "Source IP",
  "@timestamp": "Event timestamp"
}
```

## 🔍 Querying Security Data

### **Basic Queries**

1. **All Security Events**:

   ```
   *
   ```

2. **Failed Authentications**:

   ```
   class_name:"Authentication" AND activity_name:"Logon" AND status:"Failure"
   ```

3. **High Severity Events**:

   ```
   severity:"High" OR severity:"Critical"
   ```

4. **Network Anomalies**:

   ```
   class_name:"Network Activity" AND severity:"High"
   ```

5. **Terraform State Access**:
   ```
   source_name:"TerraformStateAccess"
   ```

### **Advanced Queries**

1. **Failed Logins by IP**:

   ```
   class_name:"Authentication" AND status:"Failure" AND src_endpoint.ip:*
   ```

2. **API Activity from External IPs**:

   ```
   class_name:"API Activity" AND NOT src_endpoint.ip:(10.0.0.0/8 OR 172.16.0.0/12 OR 192.168.0.0/16)
   ```

3. **Security Events in Last Hour**:
   ```
   @timestamp:[now-1h TO now] AND (severity:"High" OR severity:"Critical")
   ```

## 📈 Visualization Examples

### **Time Series Panel**

```json
{
  "targets": [
    {
      "datasource": {
        "type": "opensearch",
        "uid": "opensearch-security-logs"
      },
      "query": "class_name:\"API Activity\"",
      "timeField": "@timestamp",
      "metrics": [{ "type": "count", "id": "1" }],
      "bucketAggs": [
        {
          "type": "date_histogram",
          "field": "@timestamp",
          "id": "2",
          "settings": { "interval": "auto" }
        }
      ]
    }
  ]
}
```

### **Table Panel**

```json
{
  "targets": [
    {
      "datasource": {
        "type": "opensearch",
        "uid": "opensearch-security-logs"
      },
      "query": "severity:\"High\"",
      "timeField": "@timestamp",
      "metrics": [{ "type": "count", "id": "1" }],
      "bucketAggs": [
        {
          "type": "terms",
          "field": "actor.user.name.keyword",
          "id": "2",
          "settings": { "size": 20 }
        }
      ]
    }
  ]
}
```

## 🚨 Alerting Integration

### **Create Security Alerts**

1. **High Severity Events Alert**:

   ```json
   {
     "condition": "IS ABOVE",
     "query": "severity:\"Critical\"",
     "threshold": 0,
     "timeRange": "5m"
   }
   ```

2. **Failed Authentication Spike**:

   ```json
   {
     "condition": "IS ABOVE",
     "query": "class_name:\"Authentication\" AND status:\"Failure\"",
     "threshold": 10,
     "timeRange": "1m"
   }
   ```

3. **Terraform State Unauthorized Access**:
   ```json
   {
     "condition": "IS ABOVE",
     "query": "source_name:\"TerraformStateAccess\" AND status:\"Failure\"",
     "threshold": 0,
     "timeRange": "1m"
   }
   ```

## 🔧 Troubleshooting

### **Common Issues**

1. **Data Source Connection Failed**:

   ```bash
   # Check IAM role permissions
   kubectl describe sa kube-prometheus-stack-grafana -n monitoring

   # Verify cross-account role
   aws sts assume-role \
     --role-arn "arn:aws:iam::SECURITY-ACCOUNT-ID:role/GrafanaOpenSearchRole" \
     --role-session-name "test-session"
   ```

2. **No Data in Dashboards**:

   ```bash
   # Check OpenSearch indices
   curl -X GET "https://OPENSEARCH-ENDPOINT/_cat/indices?v" \
     --aws-sigv4 "aws:amz:us-east-1:es"

   # Verify Security Lake data ingestion
   aws securitylake list-log-sources
   ```

3. **Authentication Errors**:

   ```bash
   # Check Grafana logs
   kubectl logs -n monitoring -l app.kubernetes.io/name=grafana

   # Verify service account annotations
   kubectl get sa kube-prometheus-stack-grafana -n monitoring -o yaml
   ```

### **Debug Commands**

```bash
# Test OpenSearch connectivity
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl -X GET "https://OPENSEARCH-ENDPOINT/_cluster/health" \
  --aws-sigv4 "aws:amz:us-east-1:es"

# Check Security Lake subscriber
aws securitylake get-subscriber --subscriber-id SUBSCRIBER-ID

# Verify OCSF data format
curl -X GET "https://OPENSEARCH-ENDPOINT/security_lake_*/_search?size=1" \
  --aws-sigv4 "aws:amz:us-east-1:es"
```

## 📚 OCSF Schema Reference

### **Common OCSF Fields**

| Field             | Description       | Example                |
| ----------------- | ----------------- | ---------------------- |
| `class_name`      | Event class       | "API Activity"         |
| `activity_name`   | Specific activity | "Create", "Delete"     |
| `severity`        | Event severity    | "Critical", "High"     |
| `status`          | Operation status  | "Success", "Failure"   |
| `actor.user.name` | User identifier   | "admin@company.com"    |
| `src_endpoint.ip` | Source IP address | "203.0.113.1"          |
| `dst_endpoint.ip` | Destination IP    | "10.0.1.100"           |
| `time`            | Event timestamp   | Unix timestamp         |
| `@timestamp`      | ISO timestamp     | "2024-01-20T10:30:00Z" |

### **Security Lake Data Sources**

1. **CloudTrail** → `class_name: "API Activity"`
2. **VPC Flow Logs** → `class_name: "Network Activity"`
3. **Security Hub** → `class_name: "Security Finding"`
4. **Route53** → `class_name: "DNS Activity"`
5. **Custom Sources** → Various classes

## 🎯 Best Practices

### **Dashboard Design**

1. **You can use consistent time ranges** across panels
2. **Group related metrics** in folders
3. **Add descriptions** to panels and variables
4. **Use appropriate visualizations** for data types
5. **Implement drill-down** capabilities

### **Query Optimization**

1. **Use specific time ranges** to improve performance
2. **Filter early** in queries to reduce data processing
3. **Use keyword fields** for exact matches
4. **Aggregate data** when possible
5. **Cache frequently used queries**

### **Security Considerations**

1. **Limit dashboard access** based on roles
2. **Use read-only permissions** for data sources
3. **Audit dashboard changes** and access
4. **Implement data retention** policies
5. **Monitor query performance** and costs

## 📞 Support and Resources

### **Documentation Links**

- **Grafana OpenSearch Plugin**: https://grafana.com/docs/grafana/latest/datasources/elasticsearch/
- **OCSF Schema**: https://schema.ocsf.io/
- **AWS Security Lake**: https://docs.aws.amazon.com/security-lake/
- **OpenSearch Query DSL**: https://opensearch.org/docs/latest/query-dsl/

### **Support Contacts**

- **Platform Team**: platform-team@company.com
- **Security Team**: security-team@company.com
- **On-Call Support**: +1-XXX-XXX-XXXX

---

## 🎉 Success Metrics

With this integration, I now have:

✅ **Unified Observability**: Single pane of glass for all telemetry data
✅ **Security Visibility**: Real-time security event monitoring
✅ **Correlation Capabilities**: Link security events with application metrics
✅ **Advanced Analytics**: OCSF-normalized data for consistent querying
✅ **Operational Efficiency**: Reduced context switching between tools
✅ **Compliance Ready**: Comprehensive audit trail and monitoring

my Grafana instance now provides complete observability across infrastructure, applications, and security domains!
