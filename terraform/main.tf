provider "azurerm" {
  features {}
}

# Define variables
variable "resource_group_name" {
  default = "test-aks-rg"
}

variable "location" {
  default = "East US"
}

variable "aks_name" {
  default = "test-aks-cluster"
}

variable "node_count" {
  default = 3
}

variable "api_server_authorized_ip_ranges" {
  description = "List of IP ranges authorized to access the Kubernetes API server"
  type        = list(string)
  default     = []  # Set your allowed IPs, e.g., ["203.0.113.0/24", "198.51.100.0/24"]
}

# Resource Group
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

# Log Analytics Workspace for monitoring
resource "azurerm_log_analytics_workspace" "aks" {
  name                = "${var.aks_name}-logs"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

# AKS Cluster
resource "azurerm_kubernetes_cluster" "aks" {
  name                = var.aks_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = "testaks"

  # Security: Use private cluster to prevent public API access
  # private_cluster_enabled = true  # Uncomment for production

  # Security: Restrict API server access to specific IP ranges
  # IMPORTANT: Set var.api_server_authorized_ip_ranges with your allowed IPs
  api_server_access_profile {
    authorized_ip_ranges = var.api_server_authorized_ip_ranges
  }

  # Security: Enable RBAC (enabled by default but explicit is better)
  role_based_access_control_enabled = true

  # Security: Enable Azure AD integration for authentication
  # azure_active_directory_role_based_access_control {
  #   managed = true
  #   azure_rbac_enabled = true
  # }

  default_node_pool {
    name       = "default"
    node_count = var.node_count
    vm_size    = "Standard_B2s"

    # Security: Enable encryption at host
    # enable_host_encryption = true  # Requires subscription feature

    # Security: Use ephemeral OS disk for better security
    os_disk_type = "Managed"

    # Security: Limit node public IP
    enable_node_public_ip = false
  }

  identity {
    type = "SystemAssigned"
  }

  # Security: Enable Azure Policy for Kubernetes
  azure_policy_enabled = true

  # Security: Enable Microsoft Defender for Containers
  # microsoft_defender {
  #   log_analytics_workspace_id = azurerm_log_analytics_workspace.aks.id
  # }

  # Security: Enable OMS Agent for monitoring
  oms_agent {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.aks.id
  }

  # Security: Network profile with Azure CNI for network policies
  network_profile {
    network_plugin    = "azure"
    network_policy    = "azure"  # Enable network policies
    load_balancer_sku = "standard"
    outbound_type     = "loadBalancer"
  }

  tags = {
    environment = "dev"
    managed_by  = "terraform"
  }
}

# Output kubeconfig
output "kube_config" {
  value     = azurerm_kubernetes_cluster.aks.kube_config_raw
  sensitive = true
}

# Output cluster name for reference
output "cluster_name" {
  value = azurerm_kubernetes_cluster.aks.name
}

