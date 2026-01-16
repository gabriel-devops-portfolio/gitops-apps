# Veil Service Helm Chart

This Helm chart deploys Penumbra's Veil block explorer service on a Kubernetes cluster.

## Prerequisites

- Kubernetes 1.19+
- Helm 3.2.0+
- External Secrets Operator (optional, but recommended for managing secrets)

## Installing the Chart

To install the chart with the release name `veil`:

```bash
helm install veil ./helm/veil-service
```

### Required Environment Variables

The service requires the following environment variables to be set via a Kubernetes secret:

- `PENUMBRA_GRPC_ENDPOINT`: Penumbra gRPC endpoint URL
- `PENUMBRA_INDEXER_ENDPOINT`: Penumbra indexer endpoint URL
- `PENUMBRA_INDEXER_CA_CERT`: CA certificate for the indexer
- `PENUMBRA_CHAIN_ID`: Penumbra chain ID
- `PENUMBRA_CUILOA_URL`: URL for the Cuiloa service

### Using External Secrets Operator

This chart is designed to work with External Secrets Operator. An example ExternalSecret resource is provided in the `examples` directory.

1. Create your SecretStore resource for your secrets provider (AWS, GCP, Vault, etc.)
2. Apply the example ExternalSecret (modify it for your environment):

```bash
kubectl apply -f ./helm/veil-service/examples/external-secret.yaml
```

3. When installing the chart, set the secret name to match the one created by your ExternalSecret:

```bash
helm install veil ./helm/veil-service
```

The secret name is already set to `veil-service-secrets` in the values.yaml file.

## Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `replicaCount` | Number of replicas | `1` |
| `image.repository` | Image repository | `ghcr.io/penumbra-zone/veil` |
| `image.tag` | Image tag | `main` |
| `image.pullPolicy` | Image pull policy | `IfNotPresent` |
| `service.type` | Service type | `ClusterIP` |
| `service.port` | Service port | `3000` |
| `ingress.enabled` | Enable ingress | `false` |
| `resources` | CPU/Memory resource requests/limits | See `values.yaml` |
| `autoscaling.enabled` | Enable autoscaling | `false` |
| `existingSecret.name` | Name of the K8s Secret containing environment variables | `veil-service-secrets` |

## Exposure

The service is exposed on port 3000. To access it:

### Using port forwarding

```bash
kubectl port-forward svc/veil-service 3000:3000
```

### Using an Ingress

Set `ingress.enabled=true` and configure the `ingress.hosts` values.

## Persistence

This service doesn't require persistence as it is a stateless application.

## Upgrading

```bash
helm upgrade veil ./helm/veil-service
```