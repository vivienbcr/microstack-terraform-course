output "internal_router" {
  description = "Internal router"
  value       = openstack_networking_router_v2.internal_router
}
output "internal_net" {
  description = "Internal network"
  value       = openstack_networking_network_v2.internal_net
}
output "internal_subnet" {
  description = "Internal subnet"
  value       = openstack_networking_subnet_v2.internal_subnet
}
