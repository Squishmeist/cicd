resource "hcloud_server" "node1" {
  name        = var.server_name
  image       = var.image
  server_type = var.server_type
  location    = var.location
  public_net {
    ipv4_enabled = true
    ipv6_enabled = true
  }
}
