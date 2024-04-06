provider "openstack" {
  auth_url      = var.os_provider.auth_url
  region        = var.os_provider.region
  endpoint_type = var.os_provider.endpoint_type
  insecure      = var.os_provider.insecure
}

data "openstack_networking_network_v2" "external_network" {
  name = var.external_network_name
}

/**
* Create network INTERNAL
*/
resource "openstack_networking_network_v2" "internal_net" {
  name           = var.internal_network_name
  admin_state_up = "true"
}
/**
* Create subnet INTERNAL SUBNET
*/
resource "openstack_networking_subnet_v2" "internal_subnet" {
  name       = format("%s_subnet", var.internal_network_name)
  network_id = openstack_networking_network_v2.internal_net.id
  cidr       = var.internal_subnet_cidr
  ip_version = 4
}

/**
* Create router INTERNAL ROUTER
*/

resource "openstack_networking_router_v2" "internal_router" {
  name                = format("%s_router", var.internal_network_name)
  external_network_id = data.openstack_networking_network_v2.external_network.id
  enable_snat         = true
}

resource "openstack_networking_router_interface_v2" "internal_router_int_interface" {
  router_id = openstack_networking_router_v2.internal_router.id
  subnet_id = openstack_networking_subnet_v2.internal_subnet.id
}
