variable "os_provider" {
  type = object({
    auth_url      = string
    region        = optional(string, "microstack")
    endpoint_type = optional(string, "public")
    insecure      = optional(bool, true)
  })
}
variable "external_network_name" {
  type        = string
  description = "Name of the external network"
}

variable "internal_network_name" {
  type        = string
  description = "Name of the internal network"
}

variable "internal_subnet_cidr" {
  type        = string
  description = "CIDR of the internal subnet"
}
