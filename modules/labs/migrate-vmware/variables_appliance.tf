variable "vsphere_user" {
  description = "The username used to authenticate to vSphere"
  type        = string
}

variable "vsphere_password" {
  description = "The password used to authenticate to vSphere"
  type        = string
  sensitive   = true
}

variable "vsphere_server" {
  description = "The vCenter server address"
  type        = string
}

variable "vsphere_datacenter" {
  description = "The name of the vSphere datacenter"
  type        = string
}

variable "vsphere_folder" {
  description = "The folder in which to place the cloned VM"
  type        = string
  default     = null
}

variable "vsphere_datastore" {
  description = "The name of the datastore for the cloned VM"
  type        = string
}

variable "vsphere_compute_cluster" {
  description = "The name of the vSphere compute cluster"
  type        = string
}

variable "vsphere_network" {
  description = "The name of the network for the cloned VM"
  type        = string
}

variable "vsphere_template" {
  description = "The name of the VM template to clone"
  type        = string
}

variable "vsphere_resource_pool" {
  description = "The name of the resource pool for the cloned VM"
  type        = string
  default     = "Resources"
}

variable "vm_name" {
  description = "The name of the cloned VM"
  type        = string
}

variable "vm_admin_password" {
  description = "The admin password for the cloned VM (used for Windows customization)"
  type        = string
  sensitive   = true
}

variable "vm_hostname" {
  description = "The hostname for the cloned VM"
  type        = string
  default     = null
}

variable "vm_firmware" {
  description = "The firmware type for the VM (e.g., bios or efi)"
  type        = string
  default     = "efi"
}

variable "vm_num_cpus" {
  description = "The number of virtual CPUs assigned to the VM"
  type        = number
  default     = 2
}

variable "vm_memory" {
  description = "The memory assigned to the VM in MiB"
  type        = number
  default     = 4096
}

variable "vm_network_adapter_type" {
  description = "The network adapter type for the VM"
  type        = string
  default     = "vmxnet3"
}

variable "vm_disk_size" {
  description = "The size of the OS disk in GiB"
  type        = number
  default     = null
}

variable "vm_thin_provisioned" {
  description = "Whether the VM disks are thin provisioned"
  type        = bool
  default     = true
}

variable "vm_data_disks" {
  description = "A list of data disk configuration objects"
  type = list(object({
    label            = string
    size             = number
    eagerly_scrub    = bool
    thin_provisioned = bool
    unit_number      = number
  }))
  default = []
}