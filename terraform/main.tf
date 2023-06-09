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

variable "project_name" {
  type        = string
  default     = "defaultname"
  description = "The name of our project. Used in most resource names"
}

resource "azurerm_resource_group" "main" {
  name     = "${var.project_name}-rg"
  location = "West Europe"
  tags = {
    "purpose" = "Holds all resources associated with ${var.project_name}"
  }
}

resource "azurerm_virtual_network" "mainvnet" {
  name                = "${var.project_name}-vnet"
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

#Network Security Group for our subnet
resource "azurerm_network_security_group" "robopizza_nsg" {
  name                = "${var.project_name}-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  security_rule {
    name                       = "AllowHTTPInbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowHTTPSInbound"
    priority                   = 101
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    "purpose" = "NSG for the ${var.project_name} subnet. This is mandated by Deloitte"
  }
}

#We associate the NSG to the Subnet
resource "azurerm_subnet_network_security_group_association" "nsg_to_subnet" {
  subnet_id                 = azurerm_subnet.default_subnet.id
  network_security_group_id = azurerm_network_security_group.robopizza_nsg.id
}

#We need a container registry to hold our containers
resource "azurerm_container_registry" "robopizza_cluster_acr" {
  name                = "${var.project_name}registry"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "Basic"
  admin_enabled       = true

  tags = {
    "purpose" = "${var.project_name} Container registry"
  }
}

resource "azurerm_kubernetes_cluster" "robopizza_cluster" {
  name                = "${var.project_name}-cluster"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  dns_prefix          = "mscourse-dns"

  identity {
    type = "SystemAssigned"
  }

  default_node_pool {
    name                = "agentpool"
    enable_auto_scaling = true
    max_count           = 5
    min_count           = 1
    vm_size             = "Standard_B2s"
    vnet_subnet_id      = azurerm_subnet.default_subnet.id
    zones = [
      1, 2, 3
    ]
    tags = {
      "purpose" = "${var.project_name} Kubernetes cluster node"
    }
  }

  tags = {
    "purpose" = "${var.project_name} Kubernetes cluster"
  }
}

#Assign the cluster the rights to pull images from our container registry
resource "azurerm_role_assignment" "cluster_to_acr" {
  scope                = azurerm_container_registry.robopizza_cluster_acr.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.robopizza_cluster.kubelet_identity[0].object_id
}