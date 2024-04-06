variable "os_provider" {
  type = object({
    auth_url      = string
    region        = optional(string, "microstack")
    endpoint_type = optional(string, "public")
    insecure      = optional(bool, true)
  })
}

variable "ssh_public_key" {
  type        = string
  description = "SSH public key"
}

variable "vm_user" {
  type        = string
  description = "User to create on the VM"
  default     = "debian"
}

variable "internal_network" {
  type = object({
    name = optional(string, "internal")
    cidr = optional(string, "172.16.0.0/24")
  })
  default = {
    name = "internal"
    cidr = "172.16.0.0/24"
  }

}
