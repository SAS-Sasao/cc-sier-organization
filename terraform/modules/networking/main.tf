# =============================================================
# modules/networking/main.tf — VNet / サブネット / NSG / Private Endpoint / Private DNS Zone
# 対象案件: A社基幹システムDWH構築
# =============================================================

# -------------------------------------------------------------
# 仮想ネットワーク（DWH 基盤の閉域ネットワーク）
# -------------------------------------------------------------
resource "azurerm_virtual_network" "main" {
  name                = "vnet-${var.project_name}-${var.environment}"
  resource_group_name = var.resource_group_name
  location            = var.location
  address_space       = var.vnet_address_space

  tags = var.tags
}

# -------------------------------------------------------------
# サブネット: ADF Managed Integration Runtime 用
# -------------------------------------------------------------
resource "azurerm_subnet" "adf" {
  name                 = "snet-adf-${var.environment}"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.subnet_adf_address_prefix]

  # Private Endpoint ポリシーを無効化（PE サブネット以外も接続可能にする）
  private_endpoint_network_policies_enabled     = false
  private_link_service_network_policies_enabled = false
}

# -------------------------------------------------------------
# サブネット: Synapse Analytics 用
# -------------------------------------------------------------
resource "azurerm_subnet" "synapse" {
  name                 = "snet-synapse-${var.environment}"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.subnet_synapse_address_prefix]

  private_endpoint_network_policies_enabled     = false
  private_link_service_network_policies_enabled = false
}

# -------------------------------------------------------------
# サブネット: Private Endpoint 専用
# -------------------------------------------------------------
resource "azurerm_subnet" "private_endpoint" {
  name                 = "snet-pe-${var.environment}"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.subnet_pe_address_prefix]

  # Private Endpoint サブネットではネットワークポリシーを無効化
  private_endpoint_network_policies_enabled = false
}

# -------------------------------------------------------------
# NSG: ADF サブネット用
# 443（HTTPS）のアウトバウンドのみ許可、インバウンドはすべて拒否
# -------------------------------------------------------------
resource "azurerm_network_security_group" "adf" {
  name                = "nsg-adf-${var.environment}"
  resource_group_name = var.resource_group_name
  location            = var.location

  # ADF サービスタグとの通信を許可
  security_rule {
    name                       = "allow-adf-outbound"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "DataFactory"
  }

  # Azure Monitor へのアウトバウンドを許可（Diagnostic Settings）
  security_rule {
    name                       = "allow-monitor-outbound"
    priority                   = 110
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "AzureMonitor"
  }

  # デフォルト拒否（Azure の暗黙ルールを明示）
  security_rule {
    name                       = "deny-all-inbound"
    priority                   = 4000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = var.tags
}

resource "azurerm_subnet_network_security_group_association" "adf" {
  subnet_id                 = azurerm_subnet.adf.id
  network_security_group_id = azurerm_network_security_group.adf.id
}

# -------------------------------------------------------------
# NSG: Synapse サブネット用
# -------------------------------------------------------------
resource "azurerm_network_security_group" "synapse" {
  name                = "nsg-synapse-${var.environment}"
  resource_group_name = var.resource_group_name
  location            = var.location

  # Synapse Control Plane との通信を許可
  security_rule {
    name                       = "allow-synapse-control"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "AzureSynapseAnalytics"
    destination_address_prefix = "VirtualNetwork"
  }

  # SQL エンドポイント（1433）を VNet 内からのみ許可
  security_rule {
    name                       = "allow-sql-inbound-vnet"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "1433"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }

  tags = var.tags
}

resource "azurerm_subnet_network_security_group_association" "synapse" {
  subnet_id                 = azurerm_subnet.synapse.id
  network_security_group_id = azurerm_network_security_group.synapse.id
}

# -------------------------------------------------------------
# Private DNS Zone — Azure Blob Storage
# -------------------------------------------------------------
resource "azurerm_private_dns_zone" "blob" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "blob" {
  name                  = "pdnsl-blob-${var.environment}"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.blob.name
  virtual_network_id    = azurerm_virtual_network.main.id
  registration_enabled  = false
  tags                  = var.tags
}

# -------------------------------------------------------------
# Private DNS Zone — Azure Data Lake Storage Gen2 (DFS)
# -------------------------------------------------------------
resource "azurerm_private_dns_zone" "dfs" {
  name                = "privatelink.dfs.core.windows.net"
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "dfs" {
  name                  = "pdnsl-dfs-${var.environment}"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.dfs.name
  virtual_network_id    = azurerm_virtual_network.main.id
  registration_enabled  = false
  tags                  = var.tags
}

# -------------------------------------------------------------
# Private DNS Zone — Azure Key Vault
# -------------------------------------------------------------
resource "azurerm_private_dns_zone" "vaultcore" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "vaultcore" {
  name                  = "pdnsl-vaultcore-${var.environment}"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.vaultcore.name
  virtual_network_id    = azurerm_virtual_network.main.id
  registration_enabled  = false
  tags                  = var.tags
}

# -------------------------------------------------------------
# Private DNS Zone — Synapse SQL（Serverless / Dedicated）
# -------------------------------------------------------------
resource "azurerm_private_dns_zone" "synapse_sql" {
  name                = "privatelink.sql.azuresynapse.net"
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "synapse_sql" {
  name                  = "pdnsl-synapse-sql-${var.environment}"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.synapse_sql.name
  virtual_network_id    = azurerm_virtual_network.main.id
  registration_enabled  = false
  tags                  = var.tags
}

# -------------------------------------------------------------
# Private DNS Zone — Synapse Dev エンドポイント
# -------------------------------------------------------------
resource "azurerm_private_dns_zone" "synapse_dev" {
  name                = "privatelink.dev.azuresynapse.net"
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "synapse_dev" {
  name                  = "pdnsl-synapse-dev-${var.environment}"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.synapse_dev.name
  virtual_network_id    = azurerm_virtual_network.main.id
  registration_enabled  = false
  tags                  = var.tags
}

# -------------------------------------------------------------
# Private Endpoint — ADLS Gen2 (Blob)
# adls_storage_account_id が指定された場合のみ作成
# -------------------------------------------------------------
resource "azurerm_private_endpoint" "adls_blob" {
  count = var.adls_storage_account_id != "" ? 1 : 0

  name                = "pe-adls-blob-${var.environment}"
  resource_group_name = var.resource_group_name
  location            = var.location
  subnet_id           = azurerm_subnet.private_endpoint.id

  private_service_connection {
    name                           = "psc-adls-blob"
    private_connection_resource_id = var.adls_storage_account_id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name = "pdnszg-adls-blob"
    private_dns_zone_ids = [
      azurerm_private_dns_zone.blob.id
    ]
  }

  tags = var.tags
}

# -------------------------------------------------------------
# Private Endpoint — ADLS Gen2 (DFS)
# -------------------------------------------------------------
resource "azurerm_private_endpoint" "adls_dfs" {
  count = var.adls_storage_account_id != "" ? 1 : 0

  name                = "pe-adls-dfs-${var.environment}"
  resource_group_name = var.resource_group_name
  location            = var.location
  subnet_id           = azurerm_subnet.private_endpoint.id

  private_service_connection {
    name                           = "psc-adls-dfs"
    private_connection_resource_id = var.adls_storage_account_id
    subresource_names              = ["dfs"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name = "pdnszg-adls-dfs"
    private_dns_zone_ids = [
      azurerm_private_dns_zone.dfs.id
    ]
  }

  tags = var.tags
}

# -------------------------------------------------------------
# Private Endpoint — Synapse SQL (Serverless)
# -------------------------------------------------------------
resource "azurerm_private_endpoint" "synapse_sql" {
  count = var.synapse_workspace_id != "" ? 1 : 0

  name                = "pe-synapse-sql-${var.environment}"
  resource_group_name = var.resource_group_name
  location            = var.location
  subnet_id           = azurerm_subnet.private_endpoint.id

  private_service_connection {
    name                           = "psc-synapse-sql"
    private_connection_resource_id = var.synapse_workspace_id
    subresource_names              = ["Sql"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name = "pdnszg-synapse-sql"
    private_dns_zone_ids = [
      azurerm_private_dns_zone.synapse_sql.id
    ]
  }

  tags = var.tags
}

# -------------------------------------------------------------
# Private Endpoint — Synapse Dev エンドポイント
# -------------------------------------------------------------
resource "azurerm_private_endpoint" "synapse_dev" {
  count = var.synapse_workspace_id != "" ? 1 : 0

  name                = "pe-synapse-dev-${var.environment}"
  resource_group_name = var.resource_group_name
  location            = var.location
  subnet_id           = azurerm_subnet.private_endpoint.id

  private_service_connection {
    name                           = "psc-synapse-dev"
    private_connection_resource_id = var.synapse_workspace_id
    subresource_names              = ["Dev"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name = "pdnszg-synapse-dev"
    private_dns_zone_ids = [
      azurerm_private_dns_zone.synapse_dev.id
    ]
  }

  tags = var.tags
}

# -------------------------------------------------------------
# Private Endpoint — Azure Key Vault
# -------------------------------------------------------------
resource "azurerm_private_endpoint" "key_vault" {
  count = var.key_vault_id != "" ? 1 : 0

  name                = "pe-kv-${var.environment}"
  resource_group_name = var.resource_group_name
  location            = var.location
  subnet_id           = azurerm_subnet.private_endpoint.id

  private_service_connection {
    name                           = "psc-kv"
    private_connection_resource_id = var.key_vault_id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name = "pdnszg-kv"
    private_dns_zone_ids = [
      azurerm_private_dns_zone.vaultcore.id
    ]
  }

  tags = var.tags
}
