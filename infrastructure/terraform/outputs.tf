output "server_ip" {
  description = "Public IP address of the server"
  value       = hcloud_server.node1.ipv4_address
}

output "server_ipv6" {
  description = "IPv6 address of the server"
  value       = hcloud_server.node1.ipv6_address
}

output "server_name" {
  description = "Name of the server"
  value       = hcloud_server.node1.name
}

output "server_status" {
  description = "Status of the server"
  value       = hcloud_server.node1.status
}