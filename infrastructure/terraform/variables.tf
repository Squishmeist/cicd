variable "hcloud_token" {
  description = "Hetzner Cloud API Token"
  type        = string
  sensitive   = true
}

variable "server_name" {
  description = "Name of the server"
  type        = string
  default     = "node1"
}

variable "server_type" {
  description = "Server type/size"
  type        = string
  default     = "cax11"
}

variable "location" {
  description = "Server location"
  type        = string
  default     = "hel1"
}

variable "image" {
  description = "Server image"
  type        = string
  default     = "ubuntu-22.04"
}