###############################################################################
# Networking Module
# Creates: VNet, Subnet, Private Endpoint to Confluent, Private DNS Zone
###############################################################################

# Virtual Network
resource "azurerm_virtual_network" "this" {
  name                = var.vnet_name
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = var.vnet_address_space

  tags = var.tags
}

# Subnet for Private Endpoints
resource "azurerm_subnet" "private_endpoints" {
  name                 = "${var.vnet_name}-pe-subnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [var.pe_subnet_prefix]
}

# Subnet for AKS
resource "azurerm_subnet" "aks" {
  name                 = "${var.vnet_name}-aks-subnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [var.aks_subnet_prefix]
}

# Network Security Group for Private Endpoint Subnet
resource "azurerm_network_security_group" "pe" {
  name                = "${var.vnet_name}-pe-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = var.tags
}

resource "azurerm_subnet_network_security_group_association" "pe" {
  subnet_id                 = azurerm_subnet.private_endpoints.id
  network_security_group_id = azurerm_network_security_group.pe.id
}

# Network Security Group for AKS Subnet
resource "azurerm_network_security_group" "aks" {
  name                = "${var.vnet_name}-aks-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = var.tags
}

resource "azurerm_subnet_network_security_group_association" "aks" {
  subnet_id                 = azurerm_subnet.aks.id
  network_security_group_id = azurerm_network_security_group.aks.id
}

# Private Endpoint to Confluent Kafka Cluster
# Connects YOUR VNet to CONFLUENT'S Private Link Service (their network)
resource "azurerm_private_endpoint" "confluent" {
  name                = "${var.vnet_name}-confluent-pe"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = azurerm_subnet.private_endpoints.id

  private_service_connection {
    name                              = "confluent-psc"
    private_connection_resource_alias = var.confluent_private_link_service_aliases[var.confluent_pe_zone]
    is_manual_connection              = true
    request_message                   = "POC Private Link connection to Confluent Cloud"
  }

  tags = var.tags
}

# Private DNS Zone for Confluent cluster resolution
resource "azurerm_private_dns_zone" "confluent" {
  name                = var.confluent_dns_zone_name
  resource_group_name = var.resource_group_name

  tags = var.tags
}

# Link DNS zone to VNet
resource "azurerm_private_dns_zone_virtual_network_link" "confluent" {
  name                  = "${var.vnet_name}-confluent-dns-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.confluent.name
  virtual_network_id    = azurerm_virtual_network.this.id
  registration_enabled  = false

  tags = var.tags
}

# DNS A record for the Confluent bootstrap endpoint
resource "azurerm_private_dns_a_record" "confluent_bootstrap" {
  name                = var.confluent_dns_record_name
  zone_name           = azurerm_private_dns_zone.confluent.name
  resource_group_name = var.resource_group_name
  ttl                 = 300
  records             = [azurerm_private_endpoint.confluent.private_service_connection[0].private_ip_address]
}
