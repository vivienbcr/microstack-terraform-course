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
* Get external network 
*/
data "openstack_networking_network_v2" "external_network" {
  name = "external"
}
/**
* Get flavor for our vms
*/
data "openstack_compute_flavor_v2" "flavor_small" {
  name = "m1.small"
}
/**
* Get debian image
*/
data "openstack_images_image_v2" "debian_image" {
  name = "debian-buster"
}


/**
* Create network INTERNAL
*/
resource "openstack_networking_network_v2" "internal_net" {
  name           = "internal_net"
  admin_state_up = "true"
}
/**
* Create subnet INTERNAL SUBNET
*/
resource "openstack_networking_subnet_v2" "internal_subnet" {
  name       = "internal_subnet"
  network_id = openstack_networking_network_v2.internal_net.id
  cidr       = "172.16.0.0/24"
  ip_version = 4
}

/**
* Create router INTERNAL ROUTER
*/

resource "openstack_networking_router_v2" "internal_router" {
  name                = "my_router"
  external_network_id = data.openstack_networking_network_v2.external_network.id
  enable_snat         = true
}

resource "openstack_networking_router_interface_v2" "internal_router_int_interface" {
  router_id = openstack_networking_router_v2.internal_router.id
  subnet_id = openstack_networking_subnet_v2.internal_subnet.id
}

/**
* Create port for vm_1
*/

resource "openstack_networking_port_v2" "port_vm_1_internal" {
  name                  = "port_vm_1_internal"
  network_id            = openstack_networking_network_v2.internal_net.id
  admin_state_up        = "true"
  security_group_ids    = [openstack_networking_secgroup_v2.vm_external_secgroup.id]
  port_security_enabled = "true"

  fixed_ip {
    subnet_id = openstack_networking_subnet_v2.internal_subnet.id
  }
}


/*
* Create vm_1
*/
resource "openstack_compute_instance_v2" "vm_1" {
  name            = "vm_1"
  image_id        = data.openstack_images_image_v2.debian_image.id
  flavor_id       = data.openstack_compute_flavor_v2.flavor_small.id
  key_pair        = openstack_compute_keypair_v2.ssh_keypair.name
  security_groups = []
  user_data       = data.template_cloudinit_config.cloudinit.rendered
  network {
    port = openstack_networking_port_v2.port_vm_1_internal.id
  }
  metadata = {
    this = "that"
  }
}
/**
* Create port for vm_2
*/
resource "openstack_networking_port_v2" "port_vm_2" {
  name                  = "port_vm_2"
  network_id            = openstack_networking_network_v2.internal_net.id
  admin_state_up        = "true"
  no_security_groups    = "true"
  port_security_enabled = "false"

  fixed_ip {
    subnet_id = openstack_networking_subnet_v2.internal_subnet.id
  }
}
/*
* Create vm_2
*/
resource "openstack_compute_instance_v2" "vm_2" {
  name            = "vm_2"
  image_id        = data.openstack_images_image_v2.debian_image.id
  flavor_id       = data.openstack_compute_flavor_v2.flavor_small.id
  key_pair        = openstack_compute_keypair_v2.ssh_keypair.name
  security_groups = []
  network {
    port = openstack_networking_port_v2.port_vm_2.id
  }

  metadata = {
    this = "that"
  }
}


/**
* Create Floating IP EXTERNAL
*/

resource "openstack_networking_floatingip_v2" "external_fip_vm_1" {
  pool = data.openstack_networking_network_v2.external_network.name
}

resource "openstack_compute_floatingip_associate_v2" "external_fip_bind_vm_1" {
  floating_ip = openstack_networking_floatingip_v2.external_fip_vm_1.address
  instance_id = openstack_compute_instance_v2.vm_1.id
  depends_on  = [openstack_networking_router_v2.internal_router]
}
