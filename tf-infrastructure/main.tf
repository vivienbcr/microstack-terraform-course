provider "openstack" {
  auth_url      = var.openstack_auth_url
  region        = var.openstack_region
  endpoint_type = var.openstack_endpoint_type
}
