# Configure the Azure Provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=2.46.0"
    }
  }

  # backend configuration block
  backend "azurerm" {
    resource_group_name  = "hackerkiste-resources"
    storage_account_name = "hackerkistetfstate"
    container_name       = "tfstate"
    key                  = "mstoetzer.tfstate"
  }
}

provider "azurerm" {
  features {}
}

variable "uniquename"{
  type = string
  description = "Name for the ResourceGroup and AKS Cluster"
}

# locals block
locals {
  name     = var.uniquename
  location = "West Europe"
}

# Managed Kubernetes Cluster
resource "azurerm_resource_group" "global" {
  name     = local.name
  location = local.location
}

resource "azurerm_kubernetes_cluster" "aks" {
  name                = local.name
  resource_group_name = azurerm_resource_group.global.name
  location            = local.location
  dns_prefix          = local.name
  node_resource_group = format("%s-%s", azurerm_resource_group.global.name, "aks-rg")

  default_node_pool {
    name       = "default"
    node_count = 2
    vm_size    = "Standard_D2s_v3"
  }


  identity {
    type = "SystemAssigned"
  }
}

# Reference to a externally created Container Registry
data "azurerm_container_registry" "acr" {
  name                = "hackerkisteregistry"
  resource_group_name = "hackerkiste-resources"
}

# Registry Pull permission for the AKS Cluster
resource "azurerm_role_assignment" "acr" {
  scope                = data.azurerm_container_registry.acr.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.aks.kubelet_identity.0.object_id
}

#outputs
output "resource_group_name" {
  value = azurerm_resource_group.global.name
}

output "aks_name" {
  value = azurerm_kubernetes_cluster.aks.name
}

output "acr_name" {
  value = data.azurerm_container_registry.acr.name
}
output "acr_url" {
  value = data.azurerm_container_registry.acr.login_server
}