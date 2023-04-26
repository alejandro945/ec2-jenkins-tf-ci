output "ip_servers" {
    description = "IP de los servidores"
    value = [for server in azurerm_public_ip.devops_ip : {"name": server.id,"ip" : server.ip_address}]
}