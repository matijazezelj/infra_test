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

The setup is divided into three main steps:

1. **Terraform**: Provision the necessary cloud resources.
2. **Helm**: Deploy OpenSearch and OpenSearch Dashboards.
3. **Vector**: Collect and forward logs to OpenSearch.

## Steps

### 1. Provision Cloud Infrastructure with Terraform

This step sets up the infrastructure (Kubernetes cluster) on your cloud provider.

- **Initialize Terraform**:  
  This will initialize the working directory with Terraform configuration files.

  ```bash
  make infra-plan
  ```

- **Apply the Terraform Plan**:  
  Apply the Terraform configuration to create the Kubernetes cluster.

  ```bash
  make infra-apply
  ```

### 2. Deploy OpenSearch with Helm

We will use Helm to deploy **OpenSearch** and configure its security, including creating an **admin user**.

- **Deploy OpenSearch**:

  ```bash
  make search
  ```

  This command will:
  - Deploy OpenSearch as a **StatefulSet**.
  - Configure **authentication** and set up the **admin user** (`admin`/`YourStrongPassword1!`).
  - Set the service type to **ClusterIP** for internal access only (accessible from other services in the cluster).

### 3. Deploy OpenSearch Dashboards

**OpenSearch Dashboards** provides a web interface for interacting with OpenSearch.

- **Deploy OpenSearch Dashboards**:

  ```bash
  make dashboard
  ```

  This command will:
  - Deploy **OpenSearch Dashboards** as a **LoadBalancer** service, exposing the web UI externally on port `5601`.

### 4. Deploy Vector for Log Collection

**Vector** will collect logs from your Kubernetes environment and forward them to **OpenSearch**.

- **Deploy Vector**:

  ```bash
  make logcollector
  ```

  This command will:
  - Deploy **Vector** using Helm.
  - Configure Vector to send logs to the OpenSearch cluster.

### 5. Access the Services

- **OpenSearch Dashboards**:  
  Access the OpenSearch Dashboards UI at:

  ```bash
  https://<load-balancer-ip>:5601
  ```

  Login with:
  - **Username**: `admin`
  - **Password**: `YourStrongPassword1!`

- **OpenSearch API**:  
  OpenSearch is internally accessible via:

  ```bash
  https://opensearch-cluster-master:9200
  ```

### 6. Cleanup

To tear down the entire setup, including OpenSearch, OpenSearch Dashboards, and Vector, run the following command:

```bash
make destroy
```

This will:

- Uninstall all Helm releases (OpenSearch, OpenSearch Dashboards, and Vector).
- Delete the Kubernetes namespaces.
- Destroy the Terraform-managed cloud resources.

### Makefile Commands Overview

- **`make infra-plan`**: Generate Terraform execution plan.
- **`make infra-apply`**: Apply the Terraform plan.
- **`make infra`**: Run both `infra-plan` and `infra-apply` to provision the infrastructure.
- **`make search`**: Deploy OpenSearch.
- **`make dashboard`**: Deploy OpenSearch Dashboards.
- **`make logcollector`**: Deploy Vector (Log Collector).
- **`make destroy`**: Tear down the entire setup (Helm & Terraform).
- **`make clean`**: Remove Terraform state files locally.

---

## Security

- The **admin user** is created with the username `admin` and password `YourStrongPassword1!`.
- **OpenSearch** is not exposed publicly but can be accessed internally by **Vector** and **OpenSearch Dashboards**.
- **OpenSearch Dashboards** is exposed externally through a **LoadBalancer** on port `5601`.

## Troubleshooting

- **No logs in OpenSearch Dashboards**: Ensure that **Vector** is correctly forwarding logs to the OpenSearch instance. Check the Vector and OpenSearch logs for errors.
- **Cannot access OpenSearch Dashboards**: Verify that the LoadBalancer IP is accessible and that the firewall allows traffic on port `5601`.

## Conclusion

This setup provides a robust logging solution using **OpenSearch**, **OpenSearch Dashboards**, and **Vector**. With this configuration, you can easily scale and manage your log collection and visualization in a Kubernetes environment.

For any issues or enhancements, feel free to open an issue in the repository or reach out for help.
