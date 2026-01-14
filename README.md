# Kubernetes Log Collection with OpenSearch, Dashboards, and Vector

This setup deploys an end-to-end log collection and visualization solution using **OpenSearch**, **OpenSearch Dashboards**, and **Vector** on a Kubernetes cluster.

The architecture includes:

- **OpenSearch**: A distributed search and analytics engine.
- **OpenSearch Dashboards**: A web UI for interacting with OpenSearch.
- **Vector**: A log collector that sends logs to OpenSearch.

## Prerequisites

Before getting started, ensure the following tools are installed:

- [Terraform](https://www.terraform.io/downloads.html)
- [Helm](https://helm.sh/docs/intro/install/)
- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
- Access to a Kubernetes cluster (e.g., Azure Kubernetes Service)

## Setup Overview

The setup is divided into the following steps:

1. **Terraform**: Provision the necessary cloud resources with security hardening.
2. **Secrets**: Create Kubernetes secrets for credentials (never commit to git).
3. **Helm**: Deploy OpenSearch and OpenSearch Dashboards.
4. **Network Policies**: Apply network segmentation for security.
5. **Vector**: Collect and forward logs to OpenSearch.

## Steps

### 1. Provision Cloud Infrastructure with Terraform

This step sets up a security-hardened AKS cluster with:
- Azure Network Policies enabled
- Azure Policy for Kubernetes enabled
- Log Analytics monitoring
- Private node IPs (no public exposure)
- RBAC enabled

```bash
# Initialize and plan
make infra-plan

# Apply the configuration
make infra-apply

# Or run both together
make infra
```

### 2. Create Kubernetes Secrets

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

### 3. Deploy OpenSearch with Helm

Deploy **OpenSearch** with security features enabled:

```bash
make search
```

This command will:
- Deploy OpenSearch as a **StatefulSet** with 3 replicas.
- Configure authentication using Kubernetes Secrets.
- Run as non-root user with security context.
- Set the service type to **ClusterIP** (internal only).

### 4. Deploy OpenSearch Dashboards

Deploy **OpenSearch Dashboards** with security hardening:

```bash
make dashboard
```

This command will:
- Deploy **OpenSearch Dashboards** as a **ClusterIP** service (not exposed to internet).
- Configure secure cookie settings.
- Run as non-root user.
- Use Kubernetes Secrets for authentication.

### 5. Apply Network Policies

Restrict network traffic between components:

```bash
make network-policies
```

This applies network policies that:
- Only allow Vector to communicate with OpenSearch on port 9200.
- Only allow Dashboards to communicate with OpenSearch.
- Restrict ingress to Dashboards from ingress controller only.
- Allow OpenSearch inter-node communication on port 9300.

### 6. Deploy Vector for Log Collection

Deploy **Vector** as a DaemonSet for log collection:

```bash
make logcollector
```

This command will:
- Deploy **Vector** on all nodes using a DaemonSet.
- Configure TLS with certificate verification enabled.
- Run as non-root with read-only filesystem.
- Use disk-based buffering for reliability.
- Parse and enrich logs with transforms.

### 7. Access the Services

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

#### OpenSearch API (Internal)

OpenSearch is internally accessible via:

```
https://opensearch-cluster-master.opensearch.svc.cluster.local:9200
```

### 8. Cleanup

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

### Infrastructure (Terraform)
- ✅ Azure Network Policies enabled for pod-to-pod traffic control
- ✅ Azure Policy for Kubernetes enabled
- ✅ Log Analytics workspace for audit logging
- ✅ Private node IPs (no public exposure)
- ✅ RBAC enabled
- ✅ System-assigned managed identity

### Kubernetes Secrets
- ✅ No hardcoded passwords in configuration files
- ✅ Credentials stored in Kubernetes Secrets
- ✅ `.gitignore` configured to prevent secret commits

### Pod Security
- ✅ All pods run as non-root users (UID 1000)
- ✅ Read-only root filesystem where possible
- ✅ All capabilities dropped (`drop: ALL`)
- ✅ `allowPrivilegeEscalation: false`

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
├── terraform/
│   └── main.tf                    # AKS infrastructure with security
├── opensearch-values.yaml         # OpenSearch Helm values
├── opensearch-dashboards-values.yaml  # Dashboards Helm values
├── vector-values.yaml             # Vector Helm values
├── network-policies.yaml          # Kubernetes NetworkPolicies
├── opensearch-secret.yaml         # Secret template (DO NOT USE IN PROD)
└── rbac.yaml                      # RBAC for Vector
```

---

## Contributing

For any issues or enhancements, feel free to open an issue in the repository.
