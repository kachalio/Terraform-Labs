
### VNET, Subnet, NSG and associations ###
resource "azurerm_virtual_network" "vnet" {
  resource_group_name = var.rg_name
  name                = var.vnet_name
  address_space       = var.vnet_address_space
  location            = var.rg_location
}

resource "azurerm_subnet" "subnet" {
  name                 = var.subnet_name
  resource_group_name  = var.rg_name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = var.subnet_address_prefixes
}

resource "azurerm_network_security_group" "nsg" {
  name                = "${azurerm_virtual_network.vnet.name}-nsg"
  location            = var.rg_location
  resource_group_name = var.rg_name
}

resource "azurerm_subnet_network_security_group_association" "subnet_nsg_association" {
  subnet_id                 = azurerm_subnet.subnet.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "azurerm_public_ip" "nat_gateway_pip" {
  name                = "${azurerm_virtual_network.vnet.name}-nat-gateway-pip"
  location            = var.rg_location
  resource_group_name = var.rg_name
  allocation_method   = "Static"
  sku                 = "Standard"
  ip_tags = { "FirstPartyUsage" = "/Unprivileged" }
  tags = var.tags
  zones = []

}

### NAT Gateway and associations, for VM public access ###

resource "azurerm_nat_gateway" "nat_gateway" {
  name                = "${azurerm_virtual_network.vnet.name}-nat-gateway"
  location            = var.rg_location
  resource_group_name = var.rg_name
  sku_name            = "Standard"
}

resource "azurerm_nat_gateway_public_ip_association" "nat_gateway_pip_association" {
  nat_gateway_id = azurerm_nat_gateway.nat_gateway.id
  public_ip_address_id = azurerm_public_ip.nat_gateway_pip.id
}

resource "azurerm_subnet_nat_gateway_association" "subnet_nat_gateway_association" {
  subnet_id      = azurerm_subnet.subnet.id
  nat_gateway_id = azurerm_nat_gateway.nat_gateway.id
}