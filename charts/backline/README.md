# Backline Helm Chart

![Backline](backline.svg)

## Overview

The Backline Helm chart deploys the Backline on-premises stack to your Kubernetes cluster. 

**Chart Version:** 0.1.0  
**App Version:** 1.0.0

## Architecture

The chart deploys the following components:

- **Worker**: Main application handling code analysis workloads, AI interactions, and job orchestration
- **Janitor**: CronJob that performs automated maintenance tasks including JWT token refresh, Docker registry authentication updates, and worker image updates
- **ADOT Collector**: Sidecar container for exporting logs and traces to AWS CloudWatch and X-Ray

## Prerequisites

- Kubernetes 1.19+
- Helm 3.x
- A storage class that supports `ReadWriteMany` (RWX) access mode (e.g., NFS, EFS, CephFS)
- (Optional) AWS credentials with permissions for CloudWatch Logs and X-Ray for observability

## Installation

### Quick Start

Install the chart with required values:

```bash
helm install backline ./backline \
  --set accessKey="<your-access-key>" \
  --set baseUrl="https://your-instance.backline.ai" \
  --set logging.region="us-west-1" \
  --set logging.roleArn="arn:aws:iam::123456789012:role/YourOtelRole" \
  --create-namespace --namespace backline
```

### Installation with Custom Values File

Create a `custom-values.yaml` file with your configuration:

```yaml
baseUrl: "https://app.backline.ai"
accessKey: "your-secret-access-key"
```

Install using the custom values:

```bash
helm install backline ./backline \
  --values custom-values.yaml \
  --namespace backline
```

## Configuration Parameters

### Global Configuration

| Parameter | Description | Required | Default |
|-----------|-------------|----------|---------|
| `baseUrl` | Backline SaaS endpoint URL | Yes | `https://staging-app.backline.ai` |
| `accessKey` | Authentication key for API access | Yes | `""` |
| `namespaceOverride` | Override the default namespace | No | `backline` |
| `logging.region` | AWS region for CloudWatch and X-Ray | Yes | `""` |
| `logging.roleArn` | IAM role ARN for log shipping | Yes | `""` |

### Janitor Configuration

The Janitor component runs periodic maintenance tasks.

| Parameter | Description | Default |
|-----------|-------------|---------|
| `janitor.image.registry` | Container registry | `docker.io` |
| `janitor.image.name` | Image name | `dtzar/helm-kubectl` |
| `janitor.image.tag` | Image tag | `3.16.1` |
| `janitor.image.pullPolicy` | Image pull policy | `IfNotPresent` |
| `janitor.schedule` | CronJob schedule (cron format) | `* * * * *` (every minute) |
| `janitor.resources.requests.cpu` | CPU request | `100m` |
| `janitor.resources.requests.memory` | Memory request | `128Mi` |
| `janitor.resources.limits.cpu` | CPU limit | `200m` |
| `janitor.resources.limits.memory` | Memory limit | `256Mi` |

### Worker Configuration

The Worker is the main application component.

| Parameter | Description | Default |
|-----------|-------------|---------|
| `worker.replicaCount` | Number of worker replicas | `1` |
| `worker.image.registry` | Container registry | `580550010989.dkr.ecr.us-west-1.amazonaws.com` |
| `worker.image.name` | Image name | `prod-worker` |
| `worker.image.tag` | Image tag | `2faf8c5-1757332651` |
| `worker.image.pullPolicy` | Image pull policy | `IfNotPresent` |
| `worker.service.httpPort` | HTTP service port | `8080` |
| `worker.resources.requests.cpu` | CPU request | `500m` |
| `worker.resources.requests.memory` | Memory request | `1Gi` |
| `worker.resources.limits.cpu` | CPU limit | `2000m` |
| `worker.resources.limits.memory` | Memory limit | `2Gi` |
| `worker.livenessProbe` | Liveness probe configuration | See values.yaml |
| `worker.readinessProbe` | Readiness probe configuration | See values.yaml |
| `worker.env` | Additional environment variables | `[]` |
| `worker.nodeSelector` | Node selector for pod assignment | `{}` |
| `worker.tolerations` | Tolerations for pod assignment | `[]` |
| `worker.affinity` | Affinity rules for pod assignment | `{}` |

#### Worker Storage Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `worker.storage.pvc.create` | Create PersistentVolumeClaim | `true` |
| `worker.storage.pvc.name` | PVC name | `worker-storage` |
| `worker.storage.pvc.storageClassName` | Storage class name (empty uses cluster default) | `""` |
| `worker.storage.pvc.size` | Storage size | `10Gi` |

#### Worker OpenTelemetry Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `worker.otel.enabled` | Enable OpenTelemetry | `true` |
| `worker.otel.collector.image` | Image used to run OTEL collector | `public.ecr.aws/aws-observability/aws-otel-collector:v0.43.2` |

### Logging Configuration

Configuration for AWS CloudWatch Logs and X-Ray integration.

| Parameter | Description | Required | Default |
|-----------|-------------|----------|---------|
| `logging.region` | AWS region for CloudWatch and X-Ray | Yes | `""` |
| `logging.roleArn` | IAM role ARN for log shipping | Yes | `""` |

## Storage Requirements

The chart requires a PersistentVolume with `ReadWriteMany` (RWX) access mode. This volume is shared between:

- The Worker deployment
- Coder job pods (dynamically created for code execution)
- Dependabot upgrader job pods

**Important:** Ensure your cluster has a storage class that supports RWX access mode, such as:
- AWS EFS (via `aws-efs-csi-driver`)
- NFS
- CephFS
- GlusterFS

If your storage class doesn't support RWX, the pods will fail to mount the volume.

## Configuration Examples

### Minimal Installation

Minimal `values.yaml` for testing:

```yaml
baseUrl: "https://staging-app.backline.ai"
accessKey: "your-secret-key"
logging:
  region: "us-west-1"
  roleArn: "arn:aws:iam::123456789012:role/YourOtelRole"
```

### Production Configuration

Production-ready configuration with increased resources:

```yaml
baseUrl: "https://app.backline.ai"
accessKey: "your-secret-key"
namespaceOverride: "backline-prod"

janitor:
  schedule: "*/3 * * * *"  # Every 3 minutes
  resources:
    requests:
      cpu: "200m"
      memory: "256Mi"
    limits:
      cpu: "500m"
      memory: "512Mi"

worker:
  replicaCount: 2
  resources:
    requests:
      cpu: "1000m"
      memory: "2Gi"
    limits:
      cpu: "4000m"
      memory: "4Gi"
  storage:
    pvc:
      size: "50Gi"
  env:
    - name: MODEL_NAME
      value: "anthropic/claude-sonnet-4-20250514"

logging:
  region: "us-east-1"
  roleArn: "arn:aws:iam::123456789012:role/BacklineProdOtelRole"
```

### Custom Worker Image

Override the worker image for testing:

```yaml
baseUrl: "https://staging-app.backline.ai"
accessKey: "your-secret-key"

worker:
  image:
    registry: "my-registry.example.com"
    name: "backline-worker"
    tag: "test-feature-123"
    pullPolicy: "Always"
```

### Disable Observability

Run without AWS CloudWatch/X-Ray integration:

```yaml
baseUrl: "https://app.backline.ai"
accessKey: "your-secret-key"
logging:
  region: "us-west-1"
  roleArn: "arn:aws:iam::123456789012:role/YourOtelRole"

worker:
  otel:
    enabled: false
```

## Upgrading

Upgrade an existing release with new values:

```bash
helm upgrade backline ./backline \
  --namespace backline \
  --reuse-values \
  --set worker.image.tag=new-version
```

Or with a values file:

```bash
helm upgrade backline ./backline \
  --namespace backline \
  --values updated-values.yaml
```

## Uninstallation

Remove the Helm release:

```bash
helm uninstall backline --namespace backline
```

**Note:** The PersistentVolumeClaim may not automatically deleted if not created by the chart

## Troubleshooting

### PVC Not Mounting

**Symptom:** Pods stuck in `ContainerCreating` state with events showing volume mount errors.

**Solution:** 
- Verify your storage class supports `ReadWriteMany` access mode
- Check if the storage provisioner is running correctly
- Ensure sufficient storage is available in your cluster

```bash
kubectl get storageclass
kubectl describe pvc worker-storage -n backline
```

### Worker Pod Not Starting

**Symptom:** Worker pod in `CrashLoopBackOff` or failing health checks.

**Solution:**
- Verify `accessKey` and `baseUrl` are correct
- Check worker logs for authentication errors:

```bash
kubectl logs -n backline deployment/worker -c worker
```

### Janitor Job Failing

**Symptom:** Janitor CronJob fails repeatedly.

**Solution:**
- Check janitor logs:

```bash
kubectl logs -n backline job/janitor-<timestamp> -c janitor
```

- Common issues:
  - Invalid `accessKey`: Verify the key is correct
  - Network connectivity: Ensure the janitor can reach `baseUrl`
  - RBAC permissions: Verify the janitor ServiceAccount has proper permissions

### Image Pull Errors

**Symptom:** `ImagePullBackOff` errors on worker pods.

**Solution:**
- The janitor automatically creates and refreshes the `dockerconfig` secret
- Wait for the janitor to run (default: every minute)
- Manually trigger if needed:

```bash
kubectl create job -n backline --from=cronjob/janitor janitor-manual
```

### Logs Not Appearing in CloudWatch

**Symptom:** No logs in AWS CloudWatch Logs.

**Solution:**
- Verify the `logging.roleArn` IAM role exists and has permissions
- Check ADOT collector logs:

```bash
kubectl logs -n backline deployment/worker -c adot-collector
```

- Ensure the JWT token is being created by the janitor
- Verify AWS region in `logging.region` is correct

## Notes

- The chart automatically creates Kubernetes secrets for JWT tokens and Docker registry authentication via the janitor component
- The janitor runs periodically to refresh credentials and automatically updates the worker image to the latest version
- The ADOT sidecar ships logs to AWS CloudWatch Logs and traces to AWS X-Ray (when enabled)
- All components run with security contexts enforcing non-root users and read-only root filesystems where possible
- The worker can dynamically create Kubernetes Jobs for code execution (Coder) and dependency updates (Dependabot upgrader)

## Support

For issues, questions, or feature requests, please contact Backline support or refer to the official documentation.

