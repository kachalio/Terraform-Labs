data "azurerm_resource_group" "rg" {
  name     = "example-resource-group"
  location = var.rg_location
}