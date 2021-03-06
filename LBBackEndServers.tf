resource "azurerm_availability_set" "az_availability_set" {
  name                = "AvailSet"
  location            = azurerm_resource_group.az_project-rg.location
  resource_group_name = azurerm_resource_group.az_project-rg.name

  tags = {
    environment = "Development"
  }
  depends_on = [ azurerm_lb_rule.az_lb_rule ]
}

resource "azurerm_lb_backend_address_pool" "az_lb_backendpool" {
  loadbalancer_id = azurerm_lb.az_loadbalancer.id
  name            = "BackEndAddressPool"
  depends_on = [ azurerm_availability_set.az_availability_set ]
}

resource "azurerm_network_interface" "az_networkif" {
  count = length(var.nics)
  name                = element(var.nics, count.index)
  location            = azurerm_resource_group.az_project-rg.location
  resource_group_name = azurerm_resource_group.az_project-rg.name

  ip_configuration {
    name                          = "${var.IP_Config_Name}.${element(var.nics, count.index)}"
    subnet_id                     = azurerm_subnet.az_subnet_lb.id
    private_ip_address_allocation = "Dynamic"
  }
  depends_on = [ azurerm_lb_backend_address_pool.az_lb_backendpool ]
}

resource "azurerm_network_interface_backend_address_pool_association" "az_backend_assoc" {
  count = 2
  network_interface_id    = azurerm_network_interface.az_networkif[count.index].id
  ip_configuration_name   = "${var.IP_Config_Name}.${element(var.nics, count.index)}"
  backend_address_pool_id = azurerm_lb_backend_address_pool.az_lb_backendpool.id
  depends_on = [azurerm_network_interface.az_networkif]
}

resource "azurerm_network_security_group" "az_nwsg" {
  name                = "AZSecurityGroup"
  location            = azurerm_resource_group.az_project-rg.location
  resource_group_name = azurerm_resource_group.az_project-rg.name

  security_rule {
    name                       = "FirstSG"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    environment = "Development"
  }
  depends_on = [ azurerm_network_interface_backend_address_pool_association.az_backend_assoc ]
}

resource "azurerm_subnet_network_security_group_association" "az_nwsg_assoc" {
  subnet_id                 = azurerm_subnet.az_subnet_lb.id
  network_security_group_id = azurerm_network_security_group.az_nwsg.id
  depends_on = [ azurerm_network_security_group.az_nwsg ]
}

resource "azurerm_windows_virtual_machine" "az_VMs" {
  count = length(var.Machines)
  name                = element(var.Machines, count.index)
  resource_group_name = azurerm_resource_group.az_project-rg.name
  location            = azurerm_resource_group.az_project-rg.location
  size                = "Standard_DS1_v2"
  admin_username      = "testuser"
  admin_password      = "P@ssw0rd123"
  availability_set_id = azurerm_availability_set.az_availability_set.id
  network_interface_ids = [
      azurerm_network_interface.az_networkif[count.index].id
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2016-Datacenter"
    version   = "latest"
  }
  depends_on = [ azurerm_subnet_network_security_group_association.az_nwsg_assoc ]
}


resource "azurerm_windows_virtual_machine" "az_TestVM" {
  name                = "TestVM"
  resource_group_name = azurerm_resource_group.az_project-rg.name
  location            = azurerm_resource_group.az_project-rg.location
  size                = "Standard_DS1_V2"
  admin_username      = "testuser"
  admin_password      = "P@ssw0rd123"
  network_interface_ids = [
      azurerm_network_interface.az_networkif[2].id
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2016-Datacenter"
    version   = "latest"
  }
  depends_on = [ azurerm_windows_virtual_machine.az_VMs ]
}
