provider "azurerm" {
  features {}
}

# generate random project name
resource "random_id" "project_name" {
  byte_length = 4
}

# generate client seceret
resource "random_id" "client_secret" {
  byte_length = 32
}

# generate sql password
resource "random_id" "sql_password" {
  byte_length = 32
}

# Local for tag to attach to all items
locals {
  tags = merge(
    var.tags,
    {
      "ProjectName" = random_id.project_name.hex
    },
  )
}

# Azure Resources
resource "azurerm_resource_group" "main" {
  name     = "${random_id.project_name.hex}-rg"
  location = var.location
  tags     = local.tags
}

# Networking Module
module "networking" {
  source       = "./modules/networking"
  rg_name      = azurerm_resource_group.main.name
  location     = azurerm_resource_group.main.location
  project_name = random_id.project_name.hex
}

# Data Sources
data "azurerm_client_config" "current" {
}

data "template_file" "setup" {
  template = file("setupvault.tpl")

  vars = {
    vault_url = var.vault_url
  }
}

resource "azurerm_virtual_machine" "main" {
  name                          = "${random_id.project_name.hex}-vm"
  location                      = azurerm_resource_group.main.location
  resource_group_name           = azurerm_resource_group.main.name
  network_interface_ids         = [module.networking.network_interface]
  vm_size                       = "Standard_A2_v2"
  delete_os_disk_on_termination = true

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }

  storage_os_disk {
    name              = "${random_id.project_name.hex}vm-osdisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "${random_id.project_name.hex}vm"
    admin_username = "ubuntu"
    admin_password = "Password1234!"
    custom_data    = data.template_file.setup.rendered
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_mysql_server" "sql" {
  name                = "${random_id.project_name.hex}-mysql"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  sku_name     = "B_Gen5_2"

  storage_profile {
    storage_mb            = 5120
    backup_retention_days = 7
    geo_redundant_backup  = "Disabled"
  }

  administrator_login          = "sqladmin"
  administrator_login_password = random_id.sql_password.id
  version                      = "5.7"
  ssl_enforcement              = "Disabled"
}

resource "azurerm_mysql_database" "database" {
  name                = "exampledb"
  resource_group_name = azurerm_resource_group.main.name
  server_name         = azurerm_mysql_server.sql.name
  charset             = "utf8"
  collation           = "utf8_general_ci"
}

resource "azurerm_mysql_firewall_rule" "sql" {
  name                = "FirewallRule1"
  resource_group_name = azurerm_resource_group.main.name
  server_name         = azurerm_mysql_server.sql.name
  start_ip_address    = module.networking.public_ip
  end_ip_address      = module.networking.public_ip
}

