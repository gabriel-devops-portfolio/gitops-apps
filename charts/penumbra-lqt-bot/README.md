# 🌓 Penumbra LQT Discord Bot Helm Chart

A comprehensive Helm chart for deploying the enhanced Penumbra LQT Discord Bot with honest analytics, 3-hour scheduling, and real trading data integration.

## ✨ Enhanced Features

- **Real-time Penumbra blockchain monitoring** with honest data reporting
- **Discord analytics messages** every 3 hours with transparent estimates
- **Real trading pairs data** from Penumbra indexer PostgreSQL
- **Clean 3-row Discord embed** layout with professional styling
- **Existing secret support** for shared configuration with veil-service
- **REST API server** with health checks and webhook endpoints
- **Kubernetes-ready** deployment with comprehensive monitoring

## 🚀 Installation

### Prerequisites

- Kubernetes 1.19+
- Helm 3.2.0+
- Existing secret `veil-service-secrets` (or create new secrets)
- cert-manager (for TLS certificates, optional)

### Quick Start with Existing Secret

**Option 1: Use existing veil-service-secrets (Recommended)**

1. **Deploy with existing secret:**
   ```bash
   helm install penumbra-lqt-bot ./charts/penumbra-lqt-bot \
     --namespace penumbra \
     --set existingSecret.name="veil-service-secrets" \
     --set secrets.DISCORD_WEBHOOK_URLS="your-discord-webhook"
   ```

**Option 2: Create new secrets**

1. **Create namespace:**
   ```bash
   kubectl create namespace penumbra
   ```

2. **Create secrets:**
   ```bash
   kubectl create secret generic penumbra-lqt-bot-secret \
     --namespace=penumbra \
     --from-literal=PENUMBRA_GRPC_ENDPOINT="https://penumbra.crouton.digital" \
     --from-literal=PENUMBRA_INDEXER_ENDPOINT="postgresql://user:pass@host:port/db" \
     --from-literal=PENUMBRA_INDEXER_CA_CERT="-----BEGIN CERTIFICATE-----..." \
     --from-literal=PENUMBRA_CHAIN_ID="penumbra-1" \
     --from-literal=DISCORD_WEBHOOK_URLS="your-discord-webhook"
   ```

3. **Deploy with Helm:**
   ```bash
   helm install penumbra-lqt-bot ./charts/penumbra-lqt-bot \
     --namespace penumbra \
     --values ./values-production.yaml
   ```

## Configuration

### Values Files

The chart includes two pre-configured values files:

- `values-production.yaml`: Production-ready configuration with TLS, monitoring, and resource limits
- `values-development.yaml`: Development configuration with debug logging and relaxed limits

### Key Configuration Options

| Parameter | Description | Default |
|-----------|-------------|---------|
| `replicaCount` | Number of replicas | `1` |
| `image.repository` | Container image repository | `ghcr.io/radiantcommons/penumbra-lqt-bot` |
| `image.tag` | Container image tag | `latest` |
| `app.mode` | Bot mode (monitor, api, all) | `all` |
| `app.penumbra.rpcEndpoint` | Penumbra RPC endpoint | Required |
| `app.penumbra.grpcEndpoint` | Penumbra gRPC endpoint | Required |
| `ingress.enabled` | Enable ingress | `true` |
| `serviceMonitor.enabled` | Enable Prometheus monitoring | `true` (prod) / `false` (dev) |

### Penumbra Endpoints

Configure your Penumbra node endpoints:

```yaml
app:
  penumbra:
    rpcEndpoint: "https://rpc-penumbra.radiantcommons.com"
    grpcEndpoint: "https://penumbra-1.radiantcommons.com"
```

### Notifications

Enable platform notifications by setting the appropriate flags and creating secrets:

```yaml
discord:
  enabled: true
  embedColor: "7447FF"
  defaultTitle: "Penumbra LQT Update"

telegram:
  enabled: true

slack:
  enabled: true
```

## API Endpoints

The bot exposes several REST API endpoints:

- `GET /health` - Health check
- `GET /metrics` - Prometheus metrics
- `GET /analytics` - LQT analytics
- `GET /status` - Bot status

Example health check:
```bash
kubectl port-forward svc/penumbra-lqt-bot 8080:8080
curl http://localhost:8080/health
```

## Monitoring

### Prometheus Integration

The chart includes a ServiceMonitor for Prometheus monitoring:

```yaml
serviceMonitor:
  enabled: true
  namespace: monitoring
  labels:
    release: kube-prometheus-stack
  interval: 30s
  scrapeTimeout: 10s
```

### Metrics

Available metrics include:
- Bot uptime and health
- API request counts and latency
- Penumbra blockchain sync status
- Notification delivery status

## Security

The chart follows security best practices:

- Non-root container execution (UID 1000)
- Read-only root filesystem
- Dropped capabilities
- Security contexts configured

## Troubleshooting

### Common Issues

1. **Pod not starting:**
   ```bash
   kubectl describe pod -l app.kubernetes.io/name=penumbra-lqt-bot -n penumbra
   kubectl logs -l app.kubernetes.io/name=penumbra-lqt-bot -n penumbra
   ```

2. **API not accessible:**
   ```bash
   kubectl port-forward svc/penumbra-lqt-bot 8080:8080 -n penumbra
   curl http://localhost:8080/health
   ```

3. **Ingress not working:**
   ```bash
   kubectl get ingress -n penumbra
   kubectl describe ingress penumbra-lqt-bot -n penumbra
   ```

### Logs

View application logs:
```bash
kubectl logs -f deployment/penumbra-lqt-bot -n penumbra
```

Enable debug logging in development:
```yaml
app:
  logging:
    level: "DEBUG"
```

## Upgrading

To upgrade the deployment:

```bash
helm upgrade penumbra-lqt-bot ./charts/penumbra-lqt-bot \
  --namespace penumbra \
  --values ./values-production.yaml
```

## Uninstallation

To remove the deployment:

```bash
helm uninstall penumbra-lqt-bot --namespace penumbra
kubectl delete namespace penumbra  # Optional
```

## Contributing

Please see the main project README for contribution guidelines.

## License

This project is licensed under the MIT License - see the LICENSE file for details.
