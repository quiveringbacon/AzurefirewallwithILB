provider "azurerm" {
features {}
}


#variables
variable "A-location" {
    description = "Location of the resources"
    #default     = "eastus"
}

variable "B-resource_group_name" {
    description = "Name of the resource group to create"
}

variable "D-username" {
    description = "Username for Virtual Machines"
    #default     = "azureuser"
}

variable "E-password" {
    description = "Password for Virtual Machines"
    sensitive = true
}

resource "azurerm_resource_group" "RG" {
  location = var.A-location
  name     = var.B-resource_group_name
}

#logic app to self destruct resourcegroup after 24hrs
data "azurerm_subscription" "sub" {
}

resource "azurerm_logic_app_workflow" "workflow1" {
  location = azurerm_resource_group.RG.location
  name     = "labdelete"
  resource_group_name = azurerm_resource_group.RG.name
  identity {
    type = "SystemAssigned"
  }
  depends_on = [
    azurerm_resource_group.RG,
  ]
}
resource "azurerm_role_assignment" "contrib1" {
  scope = azurerm_resource_group.RG.id
  role_definition_name = "Contributor"
  principal_id  = azurerm_logic_app_workflow.workflow1.identity[0].principal_id
  depends_on = [azurerm_logic_app_workflow.workflow1]
}


resource "azurerm_resource_group_template_deployment" "apiconnections" {
  name                = "group-deploy"
  resource_group_name = azurerm_resource_group.RG.name
  deployment_mode     = "Incremental"
  template_content = <<TEMPLATE
{
    "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {},
    "variables": {},
    "resources": [
        {
            "type": "Microsoft.Web/connections",
            "apiVersion": "2016-06-01",
            "name": "arm-1",
            "location": "${azurerm_resource_group.RG.location}",
            "kind": "V1",
            "properties": {
                "displayName": "labdeleteconn1",
                "authenticatedUser": {},
                "statuses": [
                    {
                        "status": "Ready"
                    }
                ],
                "connectionState": "Enabled",
                "customParameterValues": {},
                "alternativeParameterValues": {},
                "parameterValueType": "Alternative",
                "createdTime": "2023-05-21T23:07:20.1346918Z",
                "changedTime": "2023-05-21T23:07:20.1346918Z",
                "api": {
                    "name": "arm",
                    "displayName": "Azure Resource Manager",
                    "description": "Azure Resource Manager exposes the APIs to manage all of your Azure resources.",
                    "iconUri": "https://connectoricons-prod.azureedge.net/laborbol/fixes/path-traversal/1.0.1552.2695/arm/icon.png",
                    "brandColor": "#003056",
                    "id": "/subscriptions/${data.azurerm_subscription.sub.subscription_id}/providers/Microsoft.Web/locations/${azurerm_resource_group.RG.location}/managedApis/arm",
                    "type": "Microsoft.Web/locations/managedApis"
                },
                "testLinks": []
            }
        },
        {
            "type": "Microsoft.Logic/workflows",
            "apiVersion": "2017-07-01",
            "name": "labdelete",
            "location": "${azurerm_resource_group.RG.location}",
            "dependsOn": [
                "[resourceId('Microsoft.Web/connections', 'arm-1')]"
            ],
            "identity": {
                "type": "SystemAssigned"
            },
            "properties": {
                "state": "Enabled",
                "definition": {
                    "$schema": "https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#",
                    "contentVersion": "1.0.0.0",
                    "parameters": {
                        "$connections": {
                            "defaultValue": {},
                            "type": "Object"
                        }
                    },
                    "triggers": {
                        "Recurrence": {
                            "recurrence": {
                                "frequency": "Minute",
                                "interval": 3,
                                "startTime": "${timeadd(timestamp(),"24h")}"
                            },
                            "evaluatedRecurrence": {
                                "frequency": "Minute",
                                "interval": 3,
                                "startTime": "${timeadd(timestamp(),"24h")}"
                            },
                            "type": "Recurrence"
                        }
                    },
                    "actions": {
                        "Delete_a_resource_group": {
                            "runAfter": {},
                            "type": "ApiConnection",
                            "inputs": {
                                "host": {
                                    "connection": {
                                        "name": "@parameters('$connections')['arm']['connectionId']"
                                    }
                                },
                                "method": "delete",
                                "path": "/subscriptions/@{encodeURIComponent('${data.azurerm_subscription.sub.subscription_id}')}/resourcegroups/@{encodeURIComponent('${azurerm_resource_group.RG.name}')}",
                                "queries": {
                                    "x-ms-api-version": "2016-06-01"
                                }
                            }
                        }
                    },
                    "outputs": {}
                },
                "parameters": {
                    "$connections": {
                        "value": {
                            "arm": {
                                "connectionId": "[resourceId('Microsoft.Web/connections', 'arm-1')]",
                                "connectionName": "arm-1",
                                "connectionProperties": {
                                    "authentication": {
                                        "type": "ManagedServiceIdentity"
                                    }
                                },
                                "id": "/subscriptions/${data.azurerm_subscription.sub.subscription_id}/providers/Microsoft.Web/locations/${azurerm_resource_group.RG.location}/managedApis/arm"
                            }
                        }
                    }
                }
            }
        }
    ]
}
TEMPLATE
}

resource "random_pet" "name" {
  length = 1
}

#log analytics workspace
resource "azurerm_log_analytics_workspace" "LAW" {
  name                = "LAW-${random_pet.name.id}"
  location            = azurerm_resource_group.RG.location
  resource_group_name = azurerm_resource_group.RG.name
  
}


#vnets and subnets
resource "azurerm_virtual_network" "hub-vnet" {
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.RG.location
  name                = "AZ-hub-vnet"
  resource_group_name = azurerm_resource_group.RG.name
  subnet {
    address_prefixes     = ["10.0.0.0/24"]
    name                 = "default"
    security_group = azurerm_network_security_group.hubvnetNSG.id
  }
  subnet {
    address_prefixes     = ["10.0.1.0/24"]
    name                 = "GatewaySubnet" 
  }
  subnet {
    address_prefixes     = ["10.0.2.0/24"]
    name                 = "AzureFirewallSubnet" 
  }
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
  
}


resource "azurerm_virtual_network" "spoke-vnet" {
  address_space       = ["10.250.0.0/16"]
  location            = azurerm_resource_group.RG.location
  name                = "AZ-spoke-vnet"
  resource_group_name = azurerm_resource_group.RG.name
  subnet {
    address_prefixes     = ["10.250.0.0/24"]
    name                 = "default"
    security_group = azurerm_network_security_group.spokevnetNSG.id
  }
  subnet {
    address_prefixes     = ["10.250.1.0/24"]
    name                 = "GatewaySubnet" 
  }
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
  
}

resource "azurerm_virtual_network_peering" "hubtospokepeering" {
  name                      = "hub-to-spoke-peering"
  remote_virtual_network_id = azurerm_virtual_network.spoke-vnet.id
  resource_group_name       = azurerm_resource_group.RG.name
  virtual_network_name      = "AZ-hub-vnet"
  allow_forwarded_traffic = true
  allow_gateway_transit = true
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
  depends_on = [
    azurerm_virtual_network.hub-vnet,
    azurerm_virtual_network.spoke-vnet,
    
  ]
}
resource "azurerm_virtual_network_peering" "spoketohubpeering" {
  name                      = "spoke-to-hub-peering"
  remote_virtual_network_id = azurerm_virtual_network.hub-vnet.id
  resource_group_name       = azurerm_resource_group.RG.name
  virtual_network_name      = "AZ-spoke-vnet"
  allow_forwarded_traffic = true
  #use_remote_gateways = true
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
  depends_on = [
    azurerm_virtual_network.spoke-vnet,
    azurerm_virtual_network.hub-vnet,
    
  ]
}

#route table
resource "azurerm_route_table" "RT" {
  name                          = "all-to-fw"
  location                      = azurerm_resource_group.RG.location
  resource_group_name           = azurerm_resource_group.RG.name
  

  route {
    name           = "inet"
    address_prefix = "0.0.0.0/0"
    next_hop_type  = "VirtualAppliance"
    next_hop_in_ip_address = "10.0.2.4"
  } 
  /* 
  route {
    name           = "tohome"
    address_prefix = "${var.C-home_public_ip}/32"
    next_hop_type  = "Internet"
    
  }
  */
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
}

resource "azurerm_subnet_route_table_association" "onhubdefaultsubnet" {
  subnet_id      = azurerm_virtual_network.hub-vnet.subnet.*.id[0]
  route_table_id = azurerm_route_table.RT.id
  timeouts {
    create = "2h"
    read = "2h"
    delete = "2h"
  }
}
resource "azurerm_subnet_route_table_association" "onspokedefaultsubnet" {
  subnet_id      = azurerm_virtual_network.spoke-vnet.subnet.*.id[0]
  route_table_id = azurerm_route_table.RT.id
  timeouts {
    create = "2h"
    read = "2h"
    delete = "2h"
  }
}

#NSG's
resource "azurerm_network_security_group" "hubvnetNSG" {
  location            = azurerm_resource_group.RG.location
  name                = "AZ-hub-vnet-default-nsg"
  resource_group_name = azurerm_resource_group.RG.name
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
  
}

resource "azurerm_network_security_group" "spokevnetNSG" {
  location            = azurerm_resource_group.RG.location
  name                = "AZ-spoke-vnet-default-nsg"
  resource_group_name = azurerm_resource_group.RG.name
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
 
}

#Public IP's

resource "azurerm_public_ip" "azfw-pip" {
  name                = "azfw-pip"
  location            = azurerm_resource_group.RG.location
  resource_group_name = azurerm_resource_group.RG.name
  allocation_method = "Static"
  sku = "Standard"
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
}

#ILB
resource "azurerm_lb" "ilb" {
  name                = "ILB"
  location            = azurerm_resource_group.RG.location
  resource_group_name = azurerm_resource_group.RG.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                          = "frontend-ip"
    subnet_id                     = azurerm_virtual_network.spoke-vnet.subnet.*.id[0]
    private_ip_address_allocation = "Static"
    private_ip_address = "10.250.0.10"
  }
}

resource "azurerm_lb_backend_address_pool" "ilb_pool" {
  loadbalancer_id      = azurerm_lb.ilb.id
  name                 = "test-pool"  
}

resource "azurerm_lb_probe" "ilb_probe" {  
  loadbalancer_id     = azurerm_lb.ilb.id
  name                = "probe1"
  port                = 80
}

resource "azurerm_lb_rule" "ilb_rule" {
  loadbalancer_id                = azurerm_lb.ilb.id
  name                           = "test-rule"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  disable_outbound_snat          = true
  frontend_ip_configuration_name = "frontend-ip"
  probe_id                       = azurerm_lb_probe.ilb_probe.id
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.ilb_pool.id]
}


#Azfirewall and policy
resource "azurerm_firewall_policy" "azfwpolicy" {
  name                = "azfw-policy"
  resource_group_name = azurerm_resource_group.RG.name
  location            = azurerm_resource_group.RG.location
  sku = "Premium"
  
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
}
resource "azurerm_firewall_policy_rule_collection_group" "azfwpolicyrcg" {
  name               = "azfwpolicy-rcg"
  firewall_policy_id = azurerm_firewall_policy.azfwpolicy.id
  priority           = 500
  network_rule_collection {
    name     = "network_rule_collection1"
    priority = 400
    action   = "Allow"
    rule {
      name                  = "network_rule_collection1_rule1"
      protocols             = ["Any"]
      source_addresses      = ["*"]
      destination_addresses = ["*"]
      destination_ports     = ["*"]
    }
  }
  nat_rule_collection {
    name = "nat_rule_collection1"
    priority = 350
    action = "Dnat"
    rule {
      name = "nat_rule1"
      protocols           = ["TCP", "UDP"]
      source_addresses    = ["*"]
      destination_address = azurerm_public_ip.azfw-pip.ip_address
      destination_ports   = ["1234"]
      translated_address  = "10.250.0.10"
      translated_port     = "80"
    }
  }
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
    }
  
}
resource "azurerm_firewall" "azfw" {
  name                = "AzureFirewall"
  location            = azurerm_resource_group.RG.location
  resource_group_name = azurerm_resource_group.RG.name
  sku_name            = "AZFW_VNet"
  sku_tier            = "Premium"
  firewall_policy_id = azurerm_firewall_policy.azfwpolicy.id

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_virtual_network.hub-vnet.subnet.*.id[2]
    public_ip_address_id = azurerm_public_ip.azfw-pip.id
  }
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
  
}

#firewall logging
resource "azurerm_monitor_diagnostic_setting" "fwlogs"{
  name = "fwlogs-${random_pet.name.id}"
  target_resource_id = azurerm_firewall.azfw.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.LAW.id
  log_analytics_destination_type = "Dedicated"

  enabled_log {
    category = "AZFWNetworkRule"
  }
  enabled_log {
    category = "AZFWApplicationRule"
  }
  enabled_log {
    category = "AZFWNatRule"
  }
  enabled_log {
    category = "AZFWThreatIntel"
  }
  enabled_log {
    category = "AZFWIdpsSignature"
  }
  enabled_log {
    category = "AZFWDnsQuery"
  }
  enabled_log {
    category = "AZFWFqdnResolveFailure"
  }
  enabled_log {
    category = "AZFWFatFlow"
  }
  enabled_log {
    category = "AZFWFlowTrace"
  }
}


#vNIC's
resource "azurerm_network_interface" "vnic" {
  count               = 2
  name                = "vnic-${count.index}"
  location            = azurerm_resource_group.RG.location
  resource_group_name = azurerm_resource_group.RG.name

  ip_configuration {
    name                          = "ipconfig${count.index}"
    subnet_id                     = azurerm_virtual_network.spoke-vnet.subnet.*.id[0]
    private_ip_address_allocation = "Dynamic"
    primary                       = true
    #public_ip_address_id = azurerm_public_ip.PIP[count.index].id
  }
}
resource "azurerm_network_interface_backend_address_pool_association" "nic_ilb_pool" {
  count                   = 2
  network_interface_id    = azurerm_network_interface.vnic[count.index].id
  ip_configuration_name   = "ipconfig${count.index}"
  backend_address_pool_id = azurerm_lb_backend_address_pool.ilb_pool.id
}


#VM's
resource "azurerm_linux_virtual_machine" "webvm" {
  count                 = 2
  name                  = "vm-${count.index}"
  location              = azurerm_resource_group.RG.location
  resource_group_name   = azurerm_resource_group.RG.name
  network_interface_ids = [azurerm_network_interface.vnic[count.index].id]
  size                  = "Standard_B2ms"

  os_disk {    
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  admin_username                  = var.D-username
  admin_password                  = var.E-password
  disable_password_authentication = false
  
}

#Install Nginx
resource "azurerm_virtual_machine_extension" "vm_extension" {
  count                = 2
  name                 = "Nginx"
  virtual_machine_id   = azurerm_linux_virtual_machine.webvm[count.index].id
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.0"

  settings = <<SETTINGS
 {
  "commandToExecute": "sudo apt-get update && sudo apt-get install nginx -y && echo '<h1>NGINX webserver-${count.index} is running</h1>' > /var/www/html/index.html && sudo systemctl restart nginx"
 }
SETTINGS

}
