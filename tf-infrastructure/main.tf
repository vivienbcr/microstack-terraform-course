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
resource "openstack_networking_secgroup_rule_v2" "ext_promexp" {
  direction         = "ingress"
  description       = "Allow Prometheus exporter access"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 9100
  port_range_max    = 9100
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.vm_external_secgroup.id
}

/**
* Get external network 
*/
data "openstack_networking_network_v2" "external_network" {
  name = "external"
}
/**
* Get flavor for our vms
*/
data "openstack_compute_flavor_v2" "flavors" {
  for_each = toset(var.vms[*].flavor)
  name     = each.value
}
/**
* Get debian image
*/
data "openstack_images_image_v2" "debian_image" {
  for_each = toset(var.vms[*].image)
  name     = each.value
}

module "internal_network" {
  source                = "./modules/internal_network"
  os_provider           = var.os_provider
  external_network_name = data.openstack_networking_network_v2.external_network.name
  internal_network_name = var.internal_network.name
  internal_subnet_cidr  = var.internal_network.cidr
}

/**
* Create port for vm_1
*/

resource "openstack_networking_port_v2" "port_vm_internal" {
  for_each              = { for i in var.vms : i.name => i.name }
  name                  = each.key
  network_id            = module.internal_network.internal_net.id
  admin_state_up        = "true"
  security_group_ids    = [openstack_networking_secgroup_v2.vm_external_secgroup.id]
  port_security_enabled = "true"

  fixed_ip {
    subnet_id = module.internal_network.internal_subnet.id
  }
}


/*
* Create vm_1
*/
resource "openstack_compute_instance_v2" "vms" {
  for_each        = { for i in var.vms : i.name => i }
  name            = each.value.name
  image_id        = data.openstack_images_image_v2.debian_image[each.value.image].id
  flavor_id       = data.openstack_compute_flavor_v2.flavors[each.value.flavor].id
  key_pair        = openstack_compute_keypair_v2.ssh_keypair.name
  security_groups = []
  user_data       = data.template_cloudinit_config.cloudinit.rendered
  network {
    port = openstack_networking_port_v2.port_vm_internal[each.value.name].id
  }
  metadata = {
    prometheus_io_port   = 9100
    prometheus_io_scrape = "true"
  }
}

/**
* Create Floating IP EXTERNAL
*/

resource "openstack_networking_floatingip_v2" "external_fip_vms" {
  count = length(var.vms)

  pool = data.openstack_networking_network_v2.external_network.name
}

resource "openstack_compute_floatingip_associate_v2" "external_fip_bind_vms" {
  count       = length(var.vms)
  floating_ip = openstack_networking_floatingip_v2.external_fip_vms[count.index].address
  instance_id = openstack_compute_instance_v2.vms[var.vms[count.index].name].id
  depends_on  = [module.internal_network]
}
