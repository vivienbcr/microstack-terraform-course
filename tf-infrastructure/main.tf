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
* Template cloud init file
*/

data "template_file" "script" {
  template = file("${path.module}/init.tftpl")

  vars = {
    user       = var.vm_user
    public_key = var.ssh_public_key
  }
}

data "template_cloudinit_config" "cloudinit" {
  gzip          = true
  base64_encode = true

  part {
    filename     = "init.cfg"
    content_type = "text/cloud-config"
    content      = data.template_file.script.rendered
  }
}

resource "local_file" "cloudinit" {
  content  = data.template_file.script.rendered
  filename = "${path.module}/cloudinit-render-preview.cfg"
}





/**
* Create security group for vms
* This security group is the same as the default security (for IPV4) group in OpenStack
* Egress accepts all traffic rules are by default https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs/resources/networking_secgroup_v2#delete_default_rules
*/
resource "openstack_networking_secgroup_v2" "vm_external_secgroup" {
  name        = "vm_external_secgroup"
  description = "Allow ICMP and SSH"

}
resource "openstack_networking_secgroup_rule_v2" "ext_ssh_in" {
  direction         = "ingress"
  description       = "Allow SSH access"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.vm_external_secgroup.id
}
resource "openstack_networking_secgroup_rule_v2" "ext_ping_in" {
  direction         = "ingress"
  description       = "Allow ICMP access"
  ethertype         = "IPv4"
  protocol          = "icmp"
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.vm_external_secgroup.id
}


/**
* Create port for vm_1
*/
resource "openstack_networking_port_v2" "port_vm_1" {
  name                  = "port_vm_1"
  network_id            = "712dc2bd-46e4-4912-a912-26660544cca6"
  admin_state_up        = "true"
  security_group_ids    = [openstack_networking_secgroup_v2.vm_external_secgroup.id]
  port_security_enabled = "true"

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
  user_data       = data.template_cloudinit_config.cloudinit.rendered
  metadata = {
    this = "that"
  }
  network {
    port = openstack_networking_port_v2.port_vm_1.id
  }
}


