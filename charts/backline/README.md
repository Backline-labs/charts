# Backline Helm Chart

## Overview
The Backline Helm chart deploys the on-premises Backline AI stack to your Kubernetes cluster.
```mermaid
graph TB
  subgraph BC["Backline Cloud (AWS)"]
      BP["Backline Platform"]
      AWB["AWS Bedrock"]
      BP --> AWB
  end
  subgraph CN["Customer Network"]
      subgraph KC["Kubernetes Cluster"]
          BW["Backline Worker (Deployment)"]
          AJJR["AI Agents Job Runner"]
          MINIO["MinIO (Object Storage)"]
          BW -->|Launch Jobs| AJJR
          BW --> MINIO
      end
  end

  SCM["Source Code Manager<br/>(GH, GitLab, Bitbucket)"]
  PM["Package Manager<br/>(npm, goproxy, maven,<br/>pip, etc.)"]

  BW <-->|HTTPS| BP
  AJJR --> SCM
  AJJR --> PM
```

**Chart Version:** 1.0.1
**App Version:** 1.0.1

## Table of Contents

- [Backline Helm Chart](#backline-helm-chart)
  - [Overview](#overview)
  - [Table of Contents](#table-of-contents)
  - [Prerequisites](#prerequisites)
  - [Architecture](#architecture)
  - [Installation](#installation)
    - [Quick Start](#quick-start)
    - [Installation with Custom Values File](#installation-with-custom-values-file)
  - [Configuration Parameters](#configuration-parameters)
    - [Global Configuration](#global-configuration)
    - [Janitor Configuration](#janitor-configuration)
    - [Worker Configuration](#worker-configuration)
      - [Worker OpenTelemetry Configuration](#worker-opentelemetry-configuration)
    - [MinIO Configuration](#minio-configuration)
    - [Resource Profiles](#resource-profiles)
  - [Network Policy Recommendations (Egress Whitelist)](#network-policy-recommendations-egress-whitelist)
    - [DNS Resolution](#dns-resolution)
    - [Package Registries](#package-registries)
    - [Container Registries](#container-registries)
    - [Source Code Managers](#source-code-managers)
    - [LLM API Access](#llm-api-access)
    - [AWS Services](#aws-services)
    - [Custom/Private Registries](#customprivate-registries)
  - [Secret Management](#secret-management)
    - [Static Secrets](#static-secrets)
    - [Dynamic Secrets](#dynamic-secrets)
    - [Troubleshooting Secret Issues](#troubleshooting-secret-issues)
  - [Configuration Examples](#configuration-examples)
    - [Minimal Installation](#minimal-installation)
    - [Advanced Configuration](#advanced-configuration)
  - [Upgrading](#upgrading)
  - [Uninstall](#uninstall)
  - [Troubleshooting](#troubleshooting)
    - [Worker Pod Not Starting](#worker-pod-not-starting)
    - [Janitor Job Failing](#janitor-job-failing)
    - [Image Pull Errors](#image-pull-errors)
  - [Support](#support)

## Prerequisites

- Kubernetes 1.19+
- Helm 3.x
- External network access to:
  - Backline AI SaaS endpoint
  - Source code management systems (GitHub, GitLab, Bitbucket)
  - Package managers (npm, Go modules, Maven, pip, etc.)

## Architecture

The chart deploys the following components:

- **Worker**: Main application handling code analysis workloads, AI interactions, and job orchestration
- **Janitor**: CronJob that performs automated maintenance tasks including JWT token refresh, Docker registry authentication updates, and worker image updates
- **ADOT Collector**: Sidecar container for exporting logs, traces, and metrics to Backline AI cloud infrastructure
- **MinIO**: Object storage for static assets and operational data (deployed as a subchart)
- **Coder Jobs**: Dynamically created Kubernetes Jobs for code execution (template embedded in worker ConfigMap)
- **Dependabot Upgrader Jobs**: Dynamically created Kubernetes Jobs for dependency updates (template embedded in worker ConfigMap)

## Installation

### Quick Start

Install the chart with required values:

```bash
# install Backline helm repository
helm repo add backline-ai https://backline-labs.github.io/charts
helm repo update backline-ai
# install the chart
helm install backline \
  backline-ai/backline \
  --namespace backline \
  --version 1.0.1 \
  --create-namespace \
  --set accessKey='<YOUR ACCESS KEY>'
```

### Installation with Custom Values File

Create a `custom-values.yaml` file with your configuration:

```yaml
accessKey: "your-secret-access-key"
environment: "production"
```

Install using the custom values:

```bash
helm install backline backline-ai/backline \
  --values custom-values.yaml \
  --namespace backline
```

## Configuration Parameters

### Global Configuration

| Parameter           | Description                                                       | Required | Default    |
| ------------------- | ----------------------------------------------------------------- | -------- | ---------- |
| `accessKey`         | Authentication key for API access                                 | Yes      | `""`       |
| `namespaceOverride` | Override the default namespace                                    | No       | `backline` |
| `environment`       | Backline AI SaaS endpoint environment (`staging` or `production`) | Yes      | `staging`  |

### Janitor Configuration

The Janitor component runs periodic maintenance tasks as a CronJob.

| Parameter                           | Description        | Default              |
| ----------------------------------- | ------------------ | -------------------- |
| `janitor.image.registry`            | Container registry | `docker.io`          |
| `janitor.image.name`                | Image name         | `dtzar/helm-kubectl` |
| `janitor.image.tag`                 | Image tag          | `3.16.1`             |
| `janitor.image.pullPolicy`          | Image pull policy  | `IfNotPresent`       |
| `janitor.resources.requests.cpu`    | CPU request        | `100m`               |
| `janitor.resources.requests.memory` | Memory request     | `128Mi`              |
| `janitor.resources.limits.cpu`      | CPU limit          | `200m`               |
| `janitor.resources.limits.memory`   | Memory limit       | `256Mi`              |

### Worker Configuration

The Worker is the main application component.

| Parameter                          | Description                                        | Default                                                |
| ---------------------------------- | -------------------------------------------------- | ------------------------------------------------------ |
| `worker.replicaCount`              | Number of worker replicas                          | `1`                                                    |
| `worker.image.name`                | Image name                                         | `prod-runner`                                          |
| `worker.image.tag`                 | Image tag                                          | `0000001-0000000001`                                   |
| `worker.image.pullPolicy`          | Image pull policy                                  | `IfNotPresent`                                         |
| `worker.service.httpPort`          | HTTP service port                                  | `8080`                                                 |
| `worker.modelName`                 | AI model for code generation tasks                 | `bedrock/us.anthropic.claude-sonnet-4-5-20250929-v1:0` |
| `worker.structuredOutputModelName` | AI model for structured output parsing             | `claude-haiku-4-5-20251001`                            |
| `worker.resources.requests.cpu`    | CPU request                                        | `500m`                                                 |
| `worker.resources.requests.memory` | Memory request                                     | `1Gi`                                                  |
| `worker.resources.limits.cpu`      | CPU limit                                          | `2000m`                                                |
| `worker.resources.limits.memory`   | Memory limit                                       | `2Gi`                                                  |
| `worker.livenessProbe`             | Liveness probe configuration                       | See values.yaml                                        |
| `worker.readinessProbe`            | Readiness probe configuration                      | See values.yaml                                        |
| `worker.env`                       | Additional environment variables                   | `[]`                                                   |
| `worker.envFromSecrets`            | List of secrets to inject as environment variables | `[]`                                                   |
| `worker.nodeSelector`              | Node selector for pod assignment                   | `{}`                                                   |
| `worker.tolerations`               | Tolerations for pod assignment                     | `[]`                                                   |
| `worker.affinity`                  | Affinity rules for pod assignment                  | `{}`                                                   |

#### Worker OpenTelemetry Configuration

| Parameter                     | Description                      | Default                                                       |
| ----------------------------- | -------------------------------- | ------------------------------------------------------------- |
| `worker.otel.enabled`         | Enable OpenTelemetry             | `true`                                                        |
| `worker.otel.collector.image` | Image used to run OTEL collector | `public.ecr.aws/aws-observability/aws-otel-collector:v0.45.1` |

### MinIO Configuration

MinIO provides object storage for static assets and operational data.

| Parameter                    | Description                            | Default                    |
| ---------------------------- | -------------------------------------- | -------------------------- |
| `minio.enabled`              | Enable MinIO subchart                  | `true`                     |
| `minio.mode`                 | MinIO deployment mode                  | `standalone`               |
| `minio.rootUser`             | MinIO root username                    | `backline`                 |
| `minio.rootPassword`         | MinIO root password                    | `backline-minio-password`  |
| `minio.persistence.enabled`  | Enable persistent storage for MinIO   | `true`                     |
| `minio.persistence.size`     | MinIO storage size                     | `10Gi`                     |
| `minio.persistence.storageClass` | Storage class for MinIO PVC       | `""`                       |
| `minio.resources.requests.cpu` | CPU request                          | `100m`                     |
| `minio.resources.requests.memory` | Memory request                    | `256Mi`                    |
| `minio.resources.limits.cpu` | CPU limit                              | `500m`                     |
| `minio.resources.limits.memory` | Memory limit                        | `512Mi`                    |
| `minio.buckets`              | List of buckets to create              | `static-assets`, `operational` |

### Resource Profiles

Resource profiles define CPU and memory allocations for ephemeral jobs (Coder and Dependabot Upgrader).

| Profile   | CPU Request | CPU Limit | Memory Request | Memory Limit |
| --------- | ----------- | --------- | -------------- | ------------ |
| `small`   | 500m        | 1000m     | 1Gi            | 2Gi          |
| `medium`  | 2000m       | 2000m     | 8Gi            | 8Gi          |
| `large`   | 4000m       | 4000m     | 16Gi           | 16Gi         |
| `xlarge`  | 8000m       | 8000m     | 32Gi           | 32Gi         |

You can customize these profiles in your values file:

```yaml
resourceProfiles:
  small:
    requests:
      cpu: "500m"
      memory: "1Gi"
    limits:
      cpu: "1000m"
      memory: "2Gi"
```

## Network Policy Recommendations (Egress Whitelist)

If your organization enforces egress network policies (e.g., using Cilium, Calico, or other CNI-based firewalls), the Backline coder pods require outbound access to various external services for package management, source code access, and LLM API connectivity.

> **Note:** Backline does not manage or enforce these egress policies. This section provides recommendations for your network/security team to configure appropriate whitelists.

### DNS Resolution

DNS resolution is **required** for FQDN-based egress rules to function.

| Target | Port | Protocol | Description |
|--------|------|----------|-------------|
| `kube-dns` (kube-system namespace) | 53 | UDP/TCP | Kubernetes internal DNS |

### Package Registries

Coder pods need access to package registries to install dependencies during code execution. Whitelist based on the languages your projects use.

#### JavaScript/Node.js (npm, yarn)

| FQDN | Port | Protocol |
|------|------|----------|
| `registry.npmjs.org` | 443 | TCP |
| `registry.yarnpkg.com` | 443 | TCP |
| `raw.githubusercontent.com` | 443 | TCP |
| `nodejs.org` | 443 | TCP |
| `*.nodejs.org` | 443 | TCP |

#### Python (PyPI, Conda)

| FQDN | Port | Protocol |
|------|------|----------|
| `pypi.org` | 443 | TCP |
| `files.pythonhosted.org` | 443 | TCP |
| `conda.anaconda.org` | 443 | TCP |
| `repo.anaconda.com` | 443 | TCP |

#### Java (Maven, Gradle)

| FQDN | Port | Protocol |
|------|------|----------|
| `repo.maven.apache.org` | 443 | TCP |
| `repo1.maven.org` | 443 | TCP |
| `search.maven.org` | 443 | TCP |
| `services.gradle.org` | 443 | TCP |
| `plugins.gradle.org` | 443 | TCP |
| `downloads.gradle.org` | 443 | TCP |

#### Go Modules

| FQDN | Port | Protocol |
|------|------|----------|
| `proxy.golang.org` | 443 | TCP |
| `sum.golang.org` | 443 | TCP |
| `storage.googleapis.com` | 443 | TCP |
| `go.dev` | 443 | TCP |

#### Rust (Cargo/crates.io)

| FQDN | Port | Protocol |
|------|------|----------|
| `crates.io` | 443 | TCP |
| `static.crates.io` | 443 | TCP |
| `index.crates.io` | 443 | TCP |

### Container Registries

For container image analysis (e.g., via skopeo), whitelist the following registries:

| Registry | FQDNs | Port | Protocol |
|----------|-------|------|----------|
| **Docker Hub** | `docker.io`, `*.docker.io`, `production.cloudflare.docker.com` | 443 | TCP |
| **Google (GCR/Artifact Registry)** | `gcr.io`, `*.gcr.io`, `*.pkg.dev` | 443 | TCP |
| **GitHub Container Registry** | `ghcr.io` | 443 | TCP |
| **Quay.io** | `quay.io` | 443 | TCP |
| **Azure Container Registry** | `*.azurecr.io` | 443 | TCP |

### Source Code Managers

Access to SCM platforms for cloning repositories and fetching code.

| Platform | FQDNs | Ports | Protocol |
|----------|-------|-------|----------|
| **GitHub** | `github.com`, `*.github.com` | 443, 22 | TCP |
| **GitLab** | `gitlab.com`, `*.gitlab.com` | 443, 22 | TCP |
| **Bitbucket** | `bitbucket.org`, `*.bitbucket.org` | 443, 22 | TCP |

> **Note:** Port 22 is required for SSH-based git operations. If your organization uses HTTPS-only, port 443 is sufficient.

### LLM API Access

For direct LLM API access (when not using the internal LiteLLM proxy):

| Provider | FQDN | Port | Protocol |
|----------|------|------|----------|
| **Anthropic** | `api.anthropic.com` | 443 | TCP |

### AWS Services

#### AWS ECR (Elastic Container Registry)

If pulling images from AWS ECR, whitelist the following pattern for each region you use:

```
<account-id>.dkr.ecr.<region>.amazonaws.com
```

**Common regions to consider:**

| Region | ECR Endpoint Pattern |
|--------|---------------------|
| us-east-1 | `*.dkr.ecr.us-east-1.amazonaws.com` |
| us-east-2 | `*.dkr.ecr.us-east-2.amazonaws.com` |
| us-west-1 | `*.dkr.ecr.us-west-1.amazonaws.com` |
| us-west-2 | `*.dkr.ecr.us-west-2.amazonaws.com` |
| eu-west-1 | `*.dkr.ecr.eu-west-1.amazonaws.com` |
| eu-west-2 | `*.dkr.ecr.eu-west-2.amazonaws.com` |
| eu-central-1 | `*.dkr.ecr.eu-central-1.amazonaws.com` |
| ap-southeast-1 | `*.dkr.ecr.ap-southeast-1.amazonaws.com` |
| ap-northeast-1 | `*.dkr.ecr.ap-northeast-1.amazonaws.com` |

### Custom/Private Registries

If your organization uses private package registries, add them to your whitelist:

#### JFrog Artifactory

| FQDN | Port | Protocol |
|------|------|----------|
| `*.jfrog.io` | 443 | TCP |

#### Other Private Registries

Add your organization-specific registries as needed:

```yaml
# Example for internal registries
- matchName: "registry.internal.company.com"
- matchName: "nexus.internal.company.com"
- matchName: "artifactory.internal.company.com"
```

### Quick Reference: Minimal Egress Whitelist

For a minimal installation, ensure at least the following are whitelisted:

| Category | Essential FQDNs |
|----------|-----------------|
| **DNS** | kube-dns (internal) |
| **Backline Cloud** | Backline SaaS endpoint (provided during onboarding) |
| **SCM** | Your SCM provider (github.com, gitlab.com, or bitbucket.org) |
| **Package Registries** | Based on your tech stack (see above) |

### Troubleshooting Network Policy Issues

**Symptom:** Coder jobs failing with network timeout errors.

**Solution:**
1. Check if egress policies are blocking required domains
2. Review pod logs for connection refused or timeout errors:

```bash
kubectl logs -n backline job/<coder-job-name>
```

3. Verify DNS resolution is working:

```bash
kubectl run -n backline dns-test --rm -it --image=busybox -- nslookup github.com
```

4. Test connectivity to specific endpoints:

```bash
kubectl run -n backline net-test --rm -it --image=curlimages/curl -- curl -I https://registry.npmjs.org
```

## Secret Management

The chart manages secrets automatically through the Janitor CronJob. Understanding this system is critical for troubleshooting authentication issues.

### Static Secrets

**`accesskey`** - Created during chart installation
- Type: `Opaque`
- Contains: `ACCESS_KEY` for API authentication
- Source: Provided via `accessKey` in values.yaml
- Lifecycle: Created once, not automatically updated

### Dynamic Secrets

The Janitor CronJob automatically creates and rotates the following secrets:

**`session-jwt`** - JWT token for AWS authentication
- Type: `Opaque`
- Contains: `token` field with JWT from Backline API
- Refresh frequency: Every 3 minutes
- Usage: Used by ADOT collector for AWS service authentication (CloudWatch, X-Ray, AMP)
- Annotation: `backline.ai/updatedAt` tracks last update timestamp (epoch seconds)

**`dockerconfig`** - Docker registry credentials
- Type: `kubernetes.io/dockerconfigjson`
- Contains: ECR authentication credentials
- Refresh frequency: Every 8 hours
- Usage: Allows worker deployment to pull images from private ECR registry

### Troubleshooting Secret Issues

**ImagePullBackOff on worker pods:**
- Wait for janitor to create/refresh the `dockerconfig` secret.
- Manually trigger: `kubectl create job -n backline --from=cronjob/janitor janitor-manual`
- Check janitor logs: `kubectl logs -n backline job/janitor-<timestamp>`

**AWS authentication failures in ADOT collector:**
- Verify `session-jwt` secret exists: `kubectl get secret -n backline session-jwt`
- Check JWT expiration and refresh: `kubectl describe secret -n backline session-jwt`
- Ensure `accessKey` is valid for the resolved base URL (derived from `environment`)

**Manual secret inspection:**
```bash
# Check all secrets
kubectl get secrets -n backline

# View secret annotations and age
kubectl describe secret -n backline session-jwt
kubectl describe secret -n backline dockerconfig

# Force janitor to run immediately
kubectl create job -n backline --from=cronjob/janitor janitor-manual
```

## Configuration Examples

### Minimal Installation

Minimal `values.yaml`:

```yaml
accessKey: "your-secret-key"
environment: "staging"
```

### Advanced Configuration

Advanced configuration with increased resources:

```yaml
accessKey: "your-secret-key"
namespaceOverride: "backline-prod"

janitor:
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
  env:
    - name: MODEL_NAME
      value: "anthropic/claude-sonnet-4-20250514"

minio:
  persistence:
    size: "50Gi"

resourceProfiles:
  medium:
    requests:
      cpu: "4000m"
      memory: "16Gi"
    limits:
      cpu: "4000m"
      memory: "16Gi"

environment: "production"
```


## Upgrading

Upgrade an existing release with new values:

```bash
helm upgrade backline \
  backline-ai/backline \
  --namespace backline \
  --reuse-values
```

Or with a values file:

```bash
helm upgrade backline \
  backline-ai/backline \
  --namespace backline \
  --values updated-values.yaml
```

## Uninstall

Remove the Helm release:

```bash
helm uninstall backline --namespace backline
```

**Note:** The PersistentVolumeClaim may not be automatically deleted if not created by the chart

## Troubleshooting

### Worker Pod Not Starting

**Symptom:** Worker pod in `CrashLoopBackOff` or failing health checks.

**Solution:**
- Verify `accessKey` and `environment` are correct.
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
  - Network connectivity: Ensure the janitor can reach the resolved base URL

### Image Pull Errors

**Symptom:** `ImagePullBackOff` errors on worker pods.

**Solution:**
- The janitor automatically creates and refreshes the `dockerconfig` secret
- Wait for the janitor to run (default: every minute)
- Manually trigger if needed:

```bash
kubectl create job -n backline --from=cronjob/janitor janitor-manual
```

## Support

For issues, questions, or feature requests, please contact [Backline support](mailto:support@backline.ai).
