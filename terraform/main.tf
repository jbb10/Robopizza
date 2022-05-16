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
  name     = "Microservices-course-rg"
  location = "North Europe"
  tags = {
    "purpose" = "dev learning"
  }
}

resource "azurerm_virtual_network" "mainvnet" {
  name                = "Microservices-course-vnet"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = ["10.0.0.0/8"]

  subnet {
    name           = "default"
    address_prefix = "10.240.0.0/16"
  }

  subnet {
    name           = "virtual-node-aci"
    address_prefix = "10.241.0.0/16"
  }
}

resource "azurerm_container_registry" "microservices_course_cluster_acr" {
  name                = "MicroservicesCourseRegistry"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "Basic"
  admin_enabled       = true
}

resource "azurerm_kubernetes_cluster" "microservices_course_cluster" {
  name                                = "Microservices-course-cluster"
  resource_group_name                 = azurerm_resource_group.main.name
  location                            = azurerm_resource_group.main.location
  dns_prefix                          = "mscourse-dns"
  private_cluster_enabled             = true
  private_cluster_public_fqdn_enabled = false
  http_application_routing_enabled    = true

  identity {
    type = "SystemAssigned"
  }

  default_node_pool {
    name                = "agentpool"
    enable_auto_scaling = true
    max_count           = 5
    min_count           = 1
    vm_size             = "Standard_B4ms"
    //vnet_subnet_id      = "/subscriptions/3aebf555-ff6c-414d-90a7-4cf0e51fa15d/resourceGroups/JbbTestSystem/providers/Microsoft.Network/virtualNetworks/JbbTestSystem-vnet/subnets/default"
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