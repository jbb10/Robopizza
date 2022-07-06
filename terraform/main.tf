# We strongly recommend using the required_providers block to set the
# Azure Provider source and version being used
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.0.0"
    }
  }
}

provider "azurerm" {
  features {}
}

#Above this line is boilerplate code
#__________________________________________________________________________
#
#Below this line are our resources

resource "azurerm_resource_group" "main" {
  name     = "Robopizza-rg"
  location = "North Europe"
  tags = {
    "purpose" = "dev learning"
  }
}

resource "azurerm_virtual_network" "mainvnet" {
  name                = "Robopizza-vnet"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = ["10.0.0.0/8"]
}

resource "azurerm_subnet" "default_subnet" {
  name                 = "default-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.mainvnet.name
  address_prefixes     = ["10.240.0.0/16"]
}

resource "azurerm_container_registry" "robopizza_cluster_acr" {
  name                = "robopizzaregistry"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "Basic"
  admin_enabled       = true
}

resource "azurerm_kubernetes_cluster" "robopizza_cluster" {
  name                                = "Robopizza-cluster"
  resource_group_name                 = azurerm_resource_group.main.name
  location                            = azurerm_resource_group.main.location
  dns_prefix                          = "mscourse-dns"

  identity {
    type = "SystemAssigned"
  }

  default_node_pool {
    name                = "agentpool"
    enable_auto_scaling = true
    max_count           = 5
    min_count           = 1
    vm_size             = "Standard_B4ms"
    vnet_subnet_id      = azurerm_subnet.default_subnet.id
    zones = [
      1, 2, 3
    ]
    tags = {
      "purpose" = "dev learning"
    }
  }

  tags = {
    "purpose" = "dev learning"
  }
}

# resource "azurerm_role_assignment" "cluster_to_acr" {
#   scope                = azurerm_container_registry.robopizza_cluster_acr.id
#   role_definition_name = "AcrPull"
#   principal_id         = azurerm_kubernetes_cluster.robopizza_cluster.kubelet_identity[0].object_id
# }