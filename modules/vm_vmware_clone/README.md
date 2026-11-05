# VMware VM clone

Clones an existing vSphere VM template with an OS disk and optional data disks.

## Guest customization

The template's configured `guest_id` selects exactly one customization block:

- IDs beginning with `win` or `longhorn` (case-insensitive) use
  `windows_options`, with `vm_name` as the computer name.
- Other IDs use `linux_options`, with `vm_name` as the host name and
  `localdomain` as the domain.

This module targets Windows and Linux templates only. A non-Windows ID is
assumed to be Linux; other guest families are not supported. Selection uses the
template's configured guest OS, not runtime OS detection. Ensure the template
has the correct guest OS configured and VMware Tools/open-vm-tools installed
and prepared for guest customization.

The empty customization `network_interface` block uses DHCP. Names must meet
the selected OS's naming requirements (including the Windows 15-character
computer-name limit).

## Inputs

Required string inputs are `vsphere_user`, `vsphere_password` (sensitive),
`vsphere_server`, `vsphere_datacenter`, `vsphere_datastore`,
`vsphere_compute_cluster`, `vsphere_network`, `vsphere_template`, and `vm_name`.

Optional inputs and their defaults are defined in [variables.tf](./variables.tf).
`vm_memory` is in MiB; disk sizes are in GiB. `vm_data_disks` accepts a list of
objects with `label`, `size`, `eagerly_scrub`, `thin_provisioned`, and
`unit_number`; its default is an empty list.

Supply credentials securely; do not commit passwords to source control.