# Penumbra Analytics Service Helm Chart

A Helm chart for deploying the Penumbra Analytics Service, which provides real-time blockchain metrics, Discord notifications, and Prometheus monitoring for the Penumbra network.

## Overview

The Penumbra Analytics Service delivers comprehensive metrics about the Penumbra blockchain including:

- **TVL (Total Value Locked)**: Real-time DEX liquidity metrics
- **Trading Volume**: 24-hour trading activity
- **Network Status**: Block height, epoch, validator count
- **LQT Tournament**: Participant counts and liquidity data
- **Staking Metrics**: Total staked UM and validator information

## Features

- Real-time data collection from Penumbra pindexer database
- Discord webhook notifications with formatted embeds
- Prometheus metrics endpoint for monitoring
- Health check endpoints
- Production-ready Kubernetes deployment

## Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `PENUMBRA_RPC_ENDPOINT` | Penumbra RPC endpoint | `https://rpc-penumbra.radiantcommons.com` |
| `PENUMBRA_GRPC_ENDPOINT` | Penumbra gRPC endpoint | `https://penumbra.crouton.digital` |
| `PENUMBRA_CHAIN_ID` | Penumbra chain identifier | `penumbra-1` |
| `UPDATE_INTERVAL_SECONDS` | Data update frequency | `30` |
| `DISCORD_INTERVAL_HOURS` | Discord notification frequency | `3` |
| `API_PORT` | API server port | `8080` |
| `METRICS_PORT` | Prometheus metrics port | `8082` |

### Secret Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `DISCORD_WEBHOOK_URL` | Discord webhook for notifications | Yes |
| `PENUMBRA_INDEXER_ENDPOINT` | PostgreSQL database connection string | Yes |
| `PENUMBRA_INDEXER_CA_CERT` | CA certificate for database SSL | Yes |

## Installation

### Using Helm

```bash
helm install penumbra-analytics-service ./charts/penumbra-analytics-service \
  --namespace penumbra \
  --create-namespace \
  --values ./ovh/config/rc-appset/values-penumbra-analytics-service.yaml
```

### Using ArgoCD ApplicationSet

The service is deployed via ArgoCD ApplicationSet with configuration in:
- Chart: `rc-gitops/charts/penumbra-analytics-service/`
- Values: `rc-gitops/ovh/config/rc-appset/values-penumbra-analytics-service.yaml`

## Monitoring

### Prometheus Metrics

The service exposes metrics on port 8082 at `/metrics`:

- `penumbra_tvl_usd`: Total Value Locked in USD
- `penumbra_volume_24h_usd`: 24-hour trading volume in USD
- `penumbra_active_validators`: Number of active validators
- `penumbra_current_epoch`: Current blockchain epoch
- `penumbra_current_height`: Current block height
- `penumbra_lqt_participants`: LQT tournament participants

### Health Checks

- `GET /health`: Service health status
- `GET /metrics`: Prometheus metrics endpoint
- `GET /api/stats`: Current blockchain statistics

## Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Pindexer DB   │────│  Analytics API   │────│  Discord Bot    │
│   (PostgreSQL)  │    │   (Port 8080)    │    │   (Webhooks)    │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                │
                                │
                       ┌──────────────────┐
                       │ Prometheus       │
                       │ (Port 8082)      │
                       └──────────────────┘
```

## Data Sources

- **Penumbra pindexer**: Real trading data from `dex_ex_aggregate_summary` table
- **Penumbra RPC**: Network status and validator information
- **Calculated metrics**: TVL aggregation and 24-hour volume calculations

## Development

### Local Development

```bash
# Set environment variables
cp .env.example .env
# Edit .env with your configuration

# Run the service
./run.sh
```

### Testing

Access the service locally:
- API: http://localhost:8080
- Metrics: http://localhost:8082/metrics
- Health: http://localhost:8080/health

## License

MIT License - see LICENSE file for details.