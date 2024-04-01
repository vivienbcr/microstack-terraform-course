provider "openstack" {
  auth_url      = var.os_provider.auth_url
  region        = var.os_provider.region
  endpoint_type = var.os_provider.endpoint_type
  insecure      = var.os_provider.insecure
}

resource "openstack_compute_keypair_v2" "ssh_keypair" {
  name       = "MyKeyPair"
  public_key = var.ssh_public_key
}

/**
* Create port for vm_1
*/
resource "openstack_networking_port_v2" "port_vm_1" {
  name                  = "port_vm_1"
  network_id            = "712dc2bd-46e4-4912-a912-26660544cca6"
  admin_state_up        = "true"
  no_security_groups    = "true"
  port_security_enabled = "false"

  fixed_ip {
    subnet_id = "35525fef-80b3-4b15-a4fc-e4347bef5a7f"
  }
}
/*
* Create vm_1
*/
resource "openstack_compute_instance_v2" "vm_1" {
  name            = "vm_1"
  image_id        = "61e8a41a-a46e-4d28-814a-d305fca3e5a3"
  flavor_id       = "2"
  key_pair        = openstack_compute_keypair_v2.ssh_keypair.name
  security_groups = []

  metadata = {
    this = "that"
  }
  network {
    port = openstack_networking_port_v2.port_vm_1.id
  }
}


