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
