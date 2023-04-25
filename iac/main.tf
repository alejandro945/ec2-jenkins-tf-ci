resource "azurerm_resource_group" "rg_devops" {
  name     = "myResourceGroup1"
  location = "East US"
}

resource "azurerm_virtual_network" "vn_devops" {
  name                = "myVNet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg_devops.location
  resource_group_name = azurerm_resource_group.rg_devops.name
}

resource "azurerm_subnet" "subnet_devops" {
  name                 = "mySubnet"
  resource_group_name  = azurerm_resource_group.rg_devops.name
  virtual_network_name = azurerm_virtual_network.vn_devops.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_public_ip" "public_ip_devops" {
  name                = "myPublicIP"
  location            = azurerm_resource_group.rg_devops.location
  resource_group_name = azurerm_resource_group.rg_devops.name
  allocation_method   = "Static"
}

resource "azurerm_network_security_group" "net_sg_devops" {
  name                = "myNetworkSecurityGroup"
  location            = azurerm_resource_group.rg_devops.location
  resource_group_name = azurerm_resource_group.rg_devops.name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "jenkins"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8080"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "sonar"
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "9000"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface" "net_inteface_devops" {
  name                = "myNIC"
  location            = azurerm_resource_group.rg_devops.location
  resource_group_name = azurerm_resource_group.rg_devops.name

  ip_configuration {
    name                          = "myNICConfg"
    subnet_id                     = azurerm_subnet.subnet_devops.id
    public_ip_address_id          = azurerm_public_ip.public_ip_devops.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_network_interface_security_group_association" "nic_sg_association" {
  network_interface_id      = azurerm_network_interface.net_inteface_devops.id
  network_security_group_id = azurerm_network_security_group.net_sg_devops.id
}

resource "azurerm_virtual_machine" "vm_devops" {
  name                  = "devopsVM"
  location              = azurerm_resource_group.rg_devops.location
  resource_group_name   = azurerm_resource_group.rg_devops.name
  network_interface_ids = [azurerm_network_interface.net_inteface_devops.id]
  vm_size               = "Standard_DS2_v2"

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }

  os_profile {
    computer_name  = "myvm"
    admin_username = var.user
    admin_password = var.password
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }

  storage_os_disk {
    name              = "myosdisk1"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  provisioner "remote-exec" {

    inline = [
      "sudo apt-get update",
      "sudo apt-get install git -y",
      "sudo apt-get install apt-transport-https ca-certificates curl software-properties-common -y",
      "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -",
      "sudo add-apt-repository \"deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable\"",
      "sudo apt-get update",
      "sudo apt-get install docker-ce -y",
      "sudo usermod -aG docker $USER",
      "sudo curl -L \"https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)\" -o /usr/local/bin/docker-compose",
      "sudo chmod +x /usr/local/bin/docker-compose",
      "sudo sysctl -w vm.max_map_count=262144",
      "sudo systemctl restart docker",
      "git clone https://github.com/Marshmillo/jenkins-sonar-nexus.git",
      "sudo docker-compose -f /home/adminuser/jenkins-sonar-nexus/docker-compose.yml up -d",
      "sudo docker exec -it jenkins jenkins-plugin-cli --plugin-file /plugins.txt",
      "sudo docker restart jenkins"
    ]

    connection {
      type = "ssh"
      user = var.user
      password = var.password
      host = azurerm_public_ip.public_ip_devops.ip_address
    }
  }

  tags = {
    environment = "terraformtest"
  }

  depends_on = [azurerm_network_interface_security_group_association.nic_sg_association]
}