# Makefile for deploying AKS, OpenSearch, and Vector

# Set variables
TERRAFORM_DIR=terraform
K8S_NAMESPACE_OPENSEARCH=opensearch
K8S_NAMESPACE_VECTOR=vector
TF_PLAN_OUTPUT=tfplan.out

.PHONY: help infra infra-plan infra-apply search dashboard logcollector destroy clean secrets network-policies sysctl

## 🆘 Display help message with available commands
help:
	@echo "Usage: make <command>"
	@echo ""
	@echo "Available commands:"
	@echo "  sysctl           - Apply sysctl configuration (required for OpenSearch)"
	@echo "  infra-plan       - Generate Terraform execution plan (Azure only)"
	@echo "  infra-apply      - Apply Terraform execution plan (Azure only)"
	@echo "  infra            - Run both plan and apply (Azure only)"
	@echo "  search           - Deploy OpenSearch (StatefulSet) with Helm"
	@echo "  dashboard        - Deploy OpenSearch Dashboards with Helm"
	@echo "  secrets          - Create Kubernetes secrets for Vector"
	@echo "  network-policies - Apply network policies for security"
	@echo "  logcollector     - Deploy Vector (Log Collector) with Helm"
	@echo "  destroy          - Uninstall Helm releases (optionally destroy Terraform)"
	@echo "  clean            - Remove Terraform state files"
	@echo ""
	@echo "Run 'make <command>' to execute."

## ⚙️ Apply sysctl configuration (required for OpenSearch)
sysctl:
	kubectl apply -f sysctl-daemonset.yaml

## 🚀 Terraform - Generate Execution Plan and Save It (Azure only)
infra-plan:
	cd $(TERRAFORM_DIR) && terraform init
	cd $(TERRAFORM_DIR) && terraform plan -out=$(TF_PLAN_OUTPUT)

## 🚀 Terraform - Apply the Execution Plan (Azure only)
infra-apply: infra-plan
	cd $(TERRAFORM_DIR) && terraform apply $(TF_PLAN_OUTPUT)

## 🚀 Terraform - Run Both Plan & Apply (Azure only)
infra: infra-apply

## 🔍 Deploy OpenSearch (StatefulSet) with Helm
search:
	helm repo add opensearch https://opensearch-project.github.io/helm-charts/
	helm repo update
	helm upgrade --install opensearch opensearch/opensearch \
	  --create-namespace --namespace $(K8S_NAMESPACE_OPENSEARCH) \
	  --values opensearch-values.yaml

## 📊 Deploy OpenSearch Dashboards with Helm
dashboard:
	helm repo add opensearch https://opensearch-project.github.io/helm-charts/
	helm repo update
	helm upgrade --install opensearch-dashboards opensearch/opensearch-dashboards \
	  --create-namespace --namespace $(K8S_NAMESPACE_OPENSEARCH) \
	  --values opensearch-dashboards-values.yaml

## � Create Kubernetes secrets for Vector
secrets:
	kubectl create namespace $(K8S_NAMESPACE_VECTOR) --dry-run=client -o yaml | kubectl apply -f -
	kubectl create namespace $(K8S_NAMESPACE_OPENSEARCH) --dry-run=client -o yaml | kubectl apply -f -
	@echo "⚠️  IMPORTANT: Create secrets with your actual passwords:"
	@echo "kubectl create secret generic opensearch-credentials --namespace $(K8S_NAMESPACE_VECTOR) --from-literal=username='admin' --from-literal=password='YOUR_SECURE_PASSWORD'"
	@echo "kubectl create secret generic opensearch-admin-secret --namespace $(K8S_NAMESPACE_OPENSEARCH) --from-literal=username='admin' --from-literal=password='YOUR_SECURE_PASSWORD'"

## 🔒 Apply network policies for security
network-policies:
	kubectl apply -f network-policies.yaml

## 📥 Deploy Vector (Log Collector) with Helm
logcollector:
	helm repo add vector https://helm.vector.dev
	helm repo update
	helm upgrade --install vector vector/vector \
	  --create-namespace --namespace $(K8S_NAMESPACE_VECTOR) \
	  --values vector-values.yaml

## 🔥 Destroy All Resources
destroy:
	@echo "Uninstalling Helm releases..."
	helm uninstall opensearch --namespace $(K8S_NAMESPACE_OPENSEARCH) --ignore-not-found
	helm uninstall opensearch-dashboards --namespace $(K8S_NAMESPACE_OPENSEARCH) --ignore-not-found
	helm uninstall vector --namespace $(K8S_NAMESPACE_VECTOR) --ignore-not-found
	
	@echo "Deleting sysctl DaemonSet..."
	kubectl delete -f sysctl-daemonset.yaml --ignore-not-found
	
	@echo "Deleting Kubernetes namespaces..."
	kubectl delete namespace $(K8S_NAMESPACE_OPENSEARCH) --ignore-not-found
	kubectl delete namespace $(K8S_NAMESPACE_VECTOR) --ignore-not-found

## 🔥 Destroy All Resources including Terraform (Azure only)
destroy-all: destroy
	@echo "Destroying Terraform resources..."
	cd $(TERRAFORM_DIR) && terraform destroy -auto-approve

## 🧹 Clean up local Terraform files
clean:
	cd $(TERRAFORM_DIR) && rm -rf .terraform terraform.tfstate* .terraform.lock.hcl $(TF_PLAN_OUTPUT)
