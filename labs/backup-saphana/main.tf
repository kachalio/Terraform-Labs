# Windows and Linux VM
# Network
# Storage
# RSV

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

resource "azurerm_resource_group" "source_rg" {
  name     = var.source_rg_name
  location = var.source_location
}

### Network Stuff ###
module "source_network" {
  source = "../../modules/network"

  rg_name                 = azurerm_resource_group.source_rg.name
  rg_location             = azurerm_resource_group.source_rg.location

  vnet_name               = var.source_vnet_name
  vnet_address_space      = var.source_vnet_address_space

  security_rules_list = var.security_rules_list
  
  subnet_name             = var.source_subnet_name
  subnet_address_prefixes = var.source_subnet_address_prefixes
  
  tags = {
    "DeployedByTerraform" = "YouBetcha"
  }
}



### VM Stuff ###

module "linux_vm" {
  source = "../../modules/vm_linux"
  count = var.linux_vm_count
  vm_name                     = "${var.linux_vm_name_prefix}-1"
  resource_group_name         = azurerm_resource_group.source_rg.name
  location                    = azurerm_resource_group.source_rg.location
  linux_vm_size               = var.vm_size
  subnet_id                   = module.source_network.subnet_id
  vm_admin_username           = var.vm_admin_username
  vm_admin_password           = var.vm_admin_password
  linux_vm_image              = var.linux_vm_image
  vm_os_disk_storage_account_type = var.linux_vm_os_disk_storage_account_type
  create_public_ip            = var.create_public_ip

  tags = {
    "DeployedByTerraform" = "YouBetcha"
  }
}

# Custom Script Extension with inline Bash script
resource "azurerm_virtual_machine_extension" "install_hana_custom_script" {
  name                 = "installHana"
  virtual_machine_id   = module.linux_vm[0].vm_id
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.1"

  protected_settings = <<PROTECTED_SETTINGS
    {
      "script": "${base64encode(<<EOT
#!/usr/bin/env bash

set -Eeuo pipefail

readonly INSTALL_DIR="/install"
readonly DOWNLOAD_MANAGER_URL="https://d149oh3iywgk04.cloudfront.net/dwnldmgr/HANA2latest/HXEDownloadManager.jar"
readonly JDK_URL="https://download.oracle.com/java/26/latest/jdk-26_linux-x64_bin.rpm"

log() {
    printf '[INFO] %s\n' "$*"
}

fail() {
    printf '[ERROR] %s\n' "$*" >&2
    exit 1
}

on_error() {
    local exit_code=$?
    printf '[ERROR] Command failed on line %s (exit code %s): %s\n' \
        "$${BASH_LINENO[0]}" "$exit_code" "$BASH_COMMAND" >&2
    exit "$exit_code"
}

trap on_error ERR

require_command() {
    command -v "$1" >/dev/null 2>&1 || fail "Required command not found: $1"
}

download() {
    local url=$1
    local destination=$2

    log "Downloading $(basename "$destination")..."
    curl --fail --location --show-error --silent \
        --retry 3 --retry-delay 2 \
        --output "$destination" "$url"
}

main() {
    [[ $EUID -eq 0 ]] || fail "This script must be run as root."

    log "Checking required commands..."
    require_command curl
    require_command rpm
    require_command zypper

    log "Creating installation directory: $INSTALL_DIR"
    mkdir -p "$INSTALL_DIR"
    cd "$INSTALL_DIR"

    download "$DOWNLOAD_MANAGER_URL" "HXEDownloadManager.jar"
    download "$JDK_URL" "jdk-26_linux-x64_bin.rpm"

    log "Installing the Java JDK..."
    rpm --upgrade --replacepkgs "jdk-26_linux-x64_bin.rpm"
    require_command java

    log "Downloading the SAP HANA trial installer..."
    java -jar "HXEDownloadManager.jar" linuxx86_64 installer "hxe.tgz" -d ./

    log "Unzip installer file..."
    tar -xzf "hxe.tgz"

    log "Installing the libltdl7 dependency..."
    zypper --non-interactive install libltdl7

    log "SAP HANA installer download completed successfully: $INSTALL_DIR/hxe.tgz"

    sudo ./setup_hxe.sh -b \
    --sid HXE \
    -i 90 \
    --hostname "$(hostname -f)" \
    --skip_proxy \
    --master_pwd "${var.hana_master_password}"

    # if fails with dependency issues, use sudo zypper lr -u to see if there's more than 1 repo configured.  Check sudo SUSEConnect --status-text to see these are registered.
}

main "$@"

EOT
)}"
    }
  PROTECTED_SETTINGS
}

module "windows_vm" {
  source = "../../modules/vm_windows"
  count = var.windows_vm_count
  vm_name                     = "${var.windows_vm_name_prefix}-1"
  resource_group_name         = azurerm_resource_group.source_rg.name
  location                    = azurerm_resource_group.source_rg.location
  windows_vm_size             = var.vm_size
  subnet_id                   = module.source_network.subnet_id
  vm_admin_username           = var.vm_admin_username
  vm_admin_password           = var.vm_admin_password
  windows_vm_image            = var.windows_vm_image
  vm_os_disk_storage_account_type = var.windows_vm_os_disk_storage_account_type
  create_public_ip            = var.create_public_ip

  tags = {
    "DeployedByTerraform" = "YouBetcha"
  }
}


resource "azurerm_recovery_services_vault" "asr_vault" {
  name                = var.rsv_name
  location            = azurerm_resource_group.source_rg.location
  resource_group_name = azurerm_resource_group.source_rg.name
  sku                 = "Standard"
  storage_mode_type   = var.rsv_storage_mode_type

  identity {
    type = "SystemAssigned"
  }

}
