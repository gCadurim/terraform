terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = ">= 2.26"
    }
  }

  required_version = ">= 0.14.9"
}

provider "azurerm" {
    skip_provider_registration = false
  features {}
}

resource "azurerm_resource_group" "stark" {
  name     = "myTFResourceGroup"
  location = "westus"
}
resource "azurerm_virtual_network" "main" {
  name                = "tf-network"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.stark.location
  resource_group_name = azurerm_resource_group.stark.name
}
resource "azurerm_subnet" "internal" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.stark.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_public_ip" "example" {
  name                = "acceptanceTestPublicIp1"
  resource_group_name = azurerm_resource_group.stark.name
  location            = azurerm_resource_group.stark.location
  allocation_method   = "Static"
}

resource "azurerm_network_security_group" "example" {
  name                = "acceptanceTestSecurityGroup1"
  location            = azurerm_resource_group.stark.location
  resource_group_name = azurerm_resource_group.stark.name

  security_rule {
    name                       = "SSH"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
      name                       = "mysql"
      priority                   = 1001
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "3306"
      source_address_prefix      = "*"
      destination_address_prefix = "*"
    }
}

resource "azurerm_network_interface" "main" {
  name                = "tf-nic"
  location            = azurerm_resource_group.stark.location
  resource_group_name = azurerm_resource_group.stark.name

  ip_configuration {
    name                          = "testconfiguration1"
    subnet_id                     = azurerm_subnet.internal.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.example.id
  }
}

resource "azurerm_virtual_machine" "main" {
  name                  = "tf-vm"
  location              = azurerm_resource_group.stark.location
  resource_group_name   = azurerm_resource_group.stark.name
  network_interface_ids = [azurerm_network_interface.main.id]
  vm_size               = "Standard_DS1_v2"

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }
  storage_os_disk {
    name              = "myosdisk1"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }
  os_profile {
    computer_name  = "tonystark"
    admin_username = "playboy"
    admin_password = "Milmilhoes!"
  }
  os_profile_linux_config {
    disable_password_authentication = false
  }
}
resource "null_resource" "install" {
    triggers = {
      order = azurerm_virtual_machine.main.id
    }
    provisioner "remote-exec"{
        connection {
            type = "ssh"
            user = "playboy"
            password = "Milmilhoes!"
            host = azurerm_public_ip.example.ip_address
        }
        inline = [
            "sudo apt-get update",
            "sudo apt-get install -y mysql-server-5.7",
        ]
    }
}
