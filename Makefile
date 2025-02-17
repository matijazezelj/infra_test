# Makefile for deploying AKS, OpenSearch, and Vector

# Set variables
TERRAFORM_DIR=terraform
K8S_NAMESPACE_OPENSEARCH=opensearch
K8S_NAMESPACE_VECTOR=vector
TF_PLAN_OUTPUT=tfplan.out

.PHONY: help infra infra-plan infra-apply search dashboard logcollector destroy clean

## 🆘 Display help message with available commands
help:
	@echo "Usage: make <command>"
	@echo ""
	@echo "Available commands:"
	@echo "  infra-plan       - Generate Terraform execution plan"
	@echo "  infra-apply      - Apply Terraform execution plan"
	@echo "  infra            - Run both plan and apply"
	@echo "  search           - Deploy OpenSearch (StatefulSet) with Helm"
	@echo "  dashboard        - Deploy OpenSearch Dashboards with Helm"
	@echo "  logcollector     - Deploy Vector (Log Collector) with Helm"
	@echo "  destroy          - Uninstall Helm releases and destroy Terraform resources"
	@echo "  clean            - Remove Terraform state files"
	@echo ""
	@echo "Run 'make <command>' to execute."

## 🚀 Terraform - Generate Execution Plan and Save It
infra-plan:
	cd $(TERRAFORM_DIR) && terraform init
	cd $(TERRAFORM_DIR) && terraform plan -out=$(TF_PLAN_OUTPUT)

## 🚀 Terraform - Apply the Execution Plan
infra-apply: infra-plan
	cd $(TERRAFORM_DIR) && terraform apply $(TF_PLAN_OUTPUT)

## 🚀 Terraform - Run Both Plan & Apply
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
	
	@echo "Deleting Kubernetes namespaces..."
	kubectl delete namespace $(K8S_NAMESPACE_OPENSEARCH) --ignore-not-found
	kubectl delete namespace $(K8S_NAMESPACE_VECTOR) --ignore-not-found

	@echo "Destroying Terraform resources..."
	cd $(TERRAFORM_DIR) && terraform destroy -auto-approve

## 🧹 Clean up local Terraform files
clean:
	cd $(TERRAFORM_DIR) && rm -rf .terraform terraform.tfstate* .terraform.lock.hcl $(TF_PLAN_OUTPUT)
