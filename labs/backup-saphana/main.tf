module "lab" {
  source = "../../modules/labs/backup-saphana"

  source_rg_name                          = var.source_rg_name
  source_location                         = var.source_location
  source_vnet_name                        = var.source_vnet_name
  source_vnet_address_space               = var.source_vnet_address_space
  source_subnet_name                      = var.source_subnet_name
  source_subnet_address_prefixes          = var.source_subnet_address_prefixes
  security_rules_list                     = var.security_rules_list
  rsv_name                                = var.rsv_name
  rsv_sku                                 = var.rsv_sku
  rsv_storage_mode_type                   = var.rsv_storage_mode_type
  vm_admin_username                       = var.vm_admin_username
  vm_admin_password                       = var.vm_admin_password
  create_public_ip                        = var.create_public_ip
  linux_vm_count                          = var.linux_vm_count
  linux_vm_name_prefix                    = var.linux_vm_name_prefix
  vm_size                                 = var.vm_size
  linux_vm_image                          = var.linux_vm_image
  linux_vm_os_disk_storage_account_type   = var.linux_vm_os_disk_storage_account_type
  windows_vm_name_prefix                  = var.windows_vm_name_prefix
  windows_vm_count                        = var.windows_vm_count
  windows_vm_image                        = var.windows_vm_image
  windows_vm_os_disk_storage_account_type = var.windows_vm_os_disk_storage_account_type
  hana_master_password                    = var.hana_master_password
}
