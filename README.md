# Kubernetes Log Collection with OpenSearch, NATS, and Vector

This setup deploys an end-to-end log collection and visualization solution using **OpenSearch**, **OpenSearch Dashboards**, **NATS JetStream**, and **Vector** on a Kubernetes cluster.

The architecture includes:

- **OpenSearch**: A distributed search and analytics engine.
- **OpenSearch Dashboards**: A web UI for interacting with OpenSearch.
- **NATS JetStream**: A lightweight message queue for log buffering and durability.
- **Vector Agent**: A log collector that sends logs to NATS.
- **Vector Aggregator**: Consumes logs from NATS and sends to OpenSearch.

## Architecture

```
┌─────────────┐     ┌─────────────┐     ┌──────────────────┐     ┌─────────────┐
│   K8s Pods  │ ──▶ │   Vector    │ ──▶ │  NATS JetStream  │ ──▶ │   Vector    │
│   (logs)    │     │   Agent     │     │     (Queue)      │     │  Aggregator │
└─────────────┘     └─────────────┘     └──────────────────┘     └──────┬──────┘
                                                                        │
                                                                        ▼
                                                               ┌─────────────────┐
                                                               │   OpenSearch    │
                                                               │    Cluster      │
                                                               └────────┬────────┘
                                                                        │
                                                                        ▼
                                                               ┌─────────────────┐
                                                               │   OpenSearch    │
                                                               │   Dashboards    │
                                                               └─────────────────┘
```

**Why NATS JetStream?**
- **Durability**: Logs are persisted in NATS, so if OpenSearch goes down, no logs are lost.
- **Backpressure handling**: NATS buffers logs during OpenSearch maintenance or outages.
- **Lightweight**: NATS uses ~10MB of memory vs. Kafka's ~300MB+.
- **Simple operations**: No ZooKeeper, minimal configuration required.

## Prerequisites

Before getting started, ensure the following tools are installed:

- [Helm](https://helm.sh/docs/intro/install/)
- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
- Access to a Kubernetes cluster (GKE, EKS, AKS, or any other)
- (Optional) [Terraform](https://www.terraform.io/downloads.html) - only if provisioning infrastructure

### Cloud-Specific Requirements

| Cloud | Network Policy CNI | Storage Class |
|-------|-------------------|---------------|
| **GKE** | Enable Dataplane V2 or Calico | `standard` (default) or `premium-rwo` |
| **EKS** | Install Calico or Cilium | `gp2` (default) or `gp3` |
| **AKS** | Enable Azure Network Policies | `managed-premium` or `default` |

## Setup Overview

The setup is divided into the following steps:

1. **Cluster Setup**: Ensure your Kubernetes cluster has Network Policy support enabled.
2. **Sysctl Configuration**: Apply the sysctl DaemonSet (required for OpenSearch).
3. **Secrets**: Create Kubernetes secrets for credentials (never commit to git).
4. **Helm**: Deploy OpenSearch, OpenSearch Dashboards, and NATS.
5. **Network Policies**: Apply network segmentation for security.
6. **Vector**: Deploy Agent (log collection) and Aggregator (send to OpenSearch).

> **Note**: Terraform is optional. This setup works with any Kubernetes cluster.

## Steps

### 1. Cluster Setup & Prerequisites

#### Option A: Use Existing Cluster

Ensure your cluster has:
- Network Policy support enabled (CNI: Calico, Cilium, or cloud-native)
- At least 3 nodes with 4GB RAM each (for OpenSearch)
- A default StorageClass for persistent volumes

**GKE Quick Setup:**
```bash
# Create cluster with Dataplane V2 (includes Network Policy support)
gcloud container clusters create my-cluster \
  --enable-dataplane-v2 \
  --zone us-central1-a \
  --num-nodes 3 \
  --machine-type e2-standard-2

# Get credentials
gcloud container clusters get-credentials my-cluster --zone us-central1-a
```

**EKS Quick Setup:**
```bash
# Create cluster (install Calico addon separately for Network Policies)
eksctl create cluster --name my-cluster --region us-east-1 --nodes 3
```

#### Option B: Use Terraform (Azure AKS)

```bash
make infra
```

### 2. Apply Sysctl Configuration

OpenSearch requires `vm.max_map_count=262144`. Apply the DaemonSet:

```bash
kubectl apply -f sysctl-daemonset.yaml
```

> **Note**: This DaemonSet requires privileged access to modify kernel parameters. It includes:\n> - Seccomp profile (`RuntimeDefault`) for system call filtering\n> - Read-only root filesystem\n> - Resource limits\n> - Pinned image version\n> - Deployed to `opensearch` namespace (created in Step 3)\n>\n> Some Trivy findings are accepted risks documented in `.trivyignore`.

### 3. Create Kubernetes Secrets

⚠️ **IMPORTANT**: Never commit passwords to version control!

Create the namespaces and secrets manually:

```bash
# Create namespaces
make secrets

# Create OpenSearch admin secret
kubectl create secret generic opensearch-admin-secret \
  --namespace opensearch \
  --from-literal=username='admin' \
  --from-literal=password='<YOUR_STRONG_PASSWORD>'

# Create Vector credentials secret
kubectl create secret generic opensearch-credentials \
  --namespace vector \
  --from-literal=username='admin' \
  --from-literal=password='<YOUR_STRONG_PASSWORD>'
```

> **Tip**: For production, use [External Secrets Operator](https://external-secrets.io/) or [HashiCorp Vault](https://www.vaultproject.io/) for secrets management.

### 4. Deploy OpenSearch with Helm

Deploy **OpenSearch** with security features enabled:

```bash
make search
```

This command will:
- Deploy OpenSearch as a **StatefulSet** with 3 replicas.
- Configure authentication using Kubernetes Secrets.
- Run as non-root user with security context.
- Set the service type to **ClusterIP** (internal only).

### 5. Deploy OpenSearch Dashboards

Deploy **OpenSearch Dashboards** with security hardening:

```bash
make dashboard
```

This command will:
- Deploy **OpenSearch Dashboards** as a **ClusterIP** service (not exposed to internet).
- Configure secure cookie settings.
- Run as non-root user.
- Use Kubernetes Secrets for authentication.

### 6. Apply Network Policies

Restrict network traffic between components:

```bash
make network-policies
```

This applies network policies that:
- Only allow Vector Agent to communicate with NATS on port 4222.
- Only allow Vector Aggregator to communicate with NATS and OpenSearch.
- Only allow Dashboards to communicate with OpenSearch.
- Restrict ingress to Dashboards from ingress controller only.
- Allow OpenSearch and NATS inter-node communication for clustering.

### 7. Deploy NATS JetStream

Deploy **NATS JetStream** for log buffering:

```bash
make queue
```

This command will:
- Deploy NATS with JetStream enabled (3 replicas for HA).
- Configure persistent storage (10Gi per node).
- Enable Prometheus metrics on port 7777.
- Allow up to 8MB message payloads.

### 8. Deploy Vector for Log Collection

Deploy **Vector Agent** and **Aggregator**:

```bash
make logcollector
```

This command will:
- Deploy **Vector Agent** on all nodes using a DaemonSet to collect logs.
- Deploy **Vector Aggregator** as a Deployment (2 replicas) to send to OpenSearch.
- Configure disk-based buffering at each layer for reliability.
- Use NATS JetStream as the queue between Agent and Aggregator.
- Enable HPA for Aggregator to scale under load.

---

## Manual Deployment (Without Makefile)

If you prefer to run Helm commands directly without the Makefile:

```bash
# 1. Apply sysctl (required for OpenSearch)
kubectl apply -f sysctl-daemonset.yaml

# 2. Create namespaces
kubectl create namespace opensearch
kubectl create namespace nats
kubectl create namespace vector

# 3. Create secrets
kubectl create secret generic opensearch-admin-secret \
  --namespace opensearch \
  --from-literal=username='admin' \
  --from-literal=password='YOUR_PASSWORD'

kubectl create secret generic opensearch-credentials \
  --namespace vector \
  --from-literal=username='admin' \
  --from-literal=password='YOUR_PASSWORD'

# 4. Add Helm repos
helm repo add opensearch https://opensearch-project.github.io/helm-charts/
helm repo add nats https://nats-io.github.io/k8s/helm/charts/
helm repo add vector https://helm.vector.dev
helm repo update

# 5. Deploy OpenSearch
helm upgrade --install opensearch opensearch/opensearch \
  --namespace opensearch \
  --values opensearch-values.yaml

# 6. Deploy OpenSearch Dashboards
helm upgrade --install opensearch-dashboards opensearch/opensearch-dashboards \
  --namespace opensearch \
  --values opensearch-dashboards-values.yaml

# 7. Deploy NATS JetStream
helm upgrade --install nats nats/nats \
  --namespace nats \
  --values nats-values.yaml

# 8. Deploy Vector Agent + Aggregator
helm upgrade --install vector-agent vector/vector \
  --namespace vector \
  --values vector-agent-values.yaml

helm upgrade --install vector-aggregator vector/vector \
  --namespace vector \
  --values vector-aggregator-values.yaml

# 9. Apply network policies
kubectl apply -f network-policies.yaml
```

---

### 9. Access the Services

#### OpenSearch Dashboards (Recommended: Use Ingress)

Since Dashboards uses ClusterIP for security, set up an Ingress with TLS:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: opensearch-dashboards
  namespace: opensearch
  annotations:
    kubernetes.io/ingress.class: nginx
    cert-manager.io/cluster-issuer: letsencrypt
spec:
  tls:
    - hosts:
        - dashboards.yourdomain.com
      secretName: dashboards-tls
  rules:
    - host: dashboards.yourdomain.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: opensearch-dashboards
                port:
                  number: 5601
```

Or use port-forwarding for local access:

```bash
kubectl port-forward svc/opensearch-dashboards 5601:5601 -n opensearch
```

Then access at: `http://localhost:5601`

**GKE-specific: Using GKE Ingress**
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: opensearch-dashboards
  namespace: opensearch
  annotations:
    kubernetes.io/ingress.class: gce
    kubernetes.io/ingress.global-static-ip-name: dashboards-ip
spec:
  rules:
    - host: dashboards.yourdomain.com
      http:
        paths:
          - path: /*
            pathType: ImplementationSpecific
            backend:
              service:
                name: opensearch-dashboards
                port:
                  number: 5601
```

#### OpenSearch API (Internal)

OpenSearch is internally accessible via:

```
https://opensearch-cluster-master.opensearch.svc.cluster.local:9200
```

### 9. Cleanup

To tear down the entire setup:

```bash
make destroy
```

This will:
- Uninstall all Helm releases.
- Delete the Kubernetes namespaces.
- Destroy the Terraform-managed cloud resources.

---

## Makefile Commands Overview

| Command | Description |
|---------|-------------|
| `make infra-plan` | Generate Terraform execution plan |
| `make infra-apply` | Apply the Terraform plan |
| `make infra` | Run both plan and apply |
| `make secrets` | Create namespaces for secrets |
| `make search` | Deploy OpenSearch |
| `make dashboard` | Deploy OpenSearch Dashboards |
| `make network-policies` | Apply network security policies |
| `make logcollector` | Deploy Vector (Log Collector) |
| `make destroy` | Tear down the entire setup |
| `make clean` | Remove Terraform state files locally |

---

## Security Features

This setup implements the following security best practices:

### Infrastructure
- ✅ Network Policies for pod-to-pod traffic control (any CNI)
- ✅ Works on GKE, EKS, AKS, or bare-metal Kubernetes
- ✅ RBAC enabled
- ✅ Persistent storage for OpenSearch data
- ✅ AKS API server access restricted to authorized IP ranges

### Kubernetes Secrets
- ✅ No hardcoded passwords in configuration files
- ✅ Credentials stored in Kubernetes Secrets
- ✅ `.gitignore` configured to prevent secret commits

### Pod Security
- ✅ All pods run as non-root users (UID 1000)
- ✅ Read-only root filesystem where possible
- ✅ All capabilities dropped (`drop: ALL`)
- ✅ `allowPrivilegeEscalation: false`
- ✅ Seccomp profiles enabled (`RuntimeDefault`)
- ⚠️ sysctl DaemonSet requires privileged (documented exception for kernel tuning)

### Network Security
- ✅ Network Policies restrict pod-to-pod communication
- ✅ OpenSearch not exposed externally (ClusterIP)
- ✅ Dashboards not exposed directly (use Ingress with TLS)
- ✅ TLS certificate verification enabled

### Application Security
- ✅ Secure cookie settings (httpOnly, sameSite: Strict)
- ✅ API playground disabled in production
- ✅ Resource limits configured

---

## Troubleshooting

### No logs in OpenSearch Dashboards
1. Check Vector pods are running: `kubectl get pods -n vector`
2. Check Vector logs: `kubectl logs -l app.kubernetes.io/name=vector -n vector`
3. Verify secrets exist: `kubectl get secrets -n vector`
4. Check network policies: `kubectl get networkpolicies -n opensearch`

### Cannot connect to OpenSearch from Vector
1. Verify the secret has correct password
2. Check TLS certificates if using custom CA
3. Verify network policy allows traffic from vector namespace

### Dashboards not accessible
1. Use port-forward: `kubectl port-forward svc/opensearch-dashboards 5601:5601 -n opensearch`
2. Check pod status: `kubectl get pods -n opensearch`
3. Verify Ingress configuration if using Ingress

### Secrets not found
Ensure you created the secrets manually as described in Step 2.

---

## File Structure

```
.
├── Makefile                       # Deployment automation
├── README.md                      # This file
├── .gitignore                     # Prevents secret commits
├── sysctl-daemonset.yaml          # vm.max_map_count config (required)
├── terraform/                     # (Optional) Azure AKS provisioning
│   └── main.tf
├── opensearch-values.yaml         # OpenSearch Helm values
├── opensearch-dashboards-values.yaml  # Dashboards Helm values
├── vector-values.yaml             # Vector Helm values
├── network-policies.yaml          # Kubernetes NetworkPolicies
├── opensearch-secret.yaml         # Secret template (DO NOT USE IN PROD)
└── rbac.yaml                      # RBAC for Vector
```

## Tested Platforms

- ✅ Google Kubernetes Engine (GKE)
- ✅ Amazon Elastic Kubernetes Service (EKS)
- ✅ Azure Kubernetes Service (AKS)
- ✅ Minikube / kind (local development)

---

## Contributing

For any issues or enhancements, feel free to open an issue in the repository.
