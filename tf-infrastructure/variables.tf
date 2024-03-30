variable "openstack_auth_url" {
  type        = string
  description = "OpenStack authentication URL"
  default     = "https://your-openstack-url/auth"
}

variable "openstack_region" {
  type        = string
  description = "OpenStack region"
  default     = "microstack"
}

variable "openstack_endpoint_type" {
  type        = string
  description = "OpenStack endpoint type"
  default     = "public"
}

variable "openstack_disable_ssl_certificate_validation" {
  type        = bool
  description = "Disable SSL certificate validation, recommended for microstack"
  default     = true
}
