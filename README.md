# Azure firewall with internal load balancer

This creates a hub vnet that is peered with a spoke vnet.  An Azure Firewall is in the hub vnet with a DNAT rule sending port 1234 to an in internal load balancer on port 80 with a pair of linux webservers in the backend pool. The load balancer and web servers are in the spoke vnet. You'll be prompted for the resource group name, location where you want the resources created, and username and password to use for the VM's. This also creates a logic app that will delete the resource group in 24hrs. The topology will look something like this:

![azfwlab-withILB](https://github.com/quiveringbacon/AzurefirewallwithILB/assets/128983862/6d908ad3-5b3f-4a25-ab4e-641eddccd06b)

You can run Terraform right from the Azure cloud shell by cloning this git repository with "git clone https://github.com/quiveringbacon/AzurefirewallwithILB.git ./terraform". Then, "cd terraform" then, "terraform init" and finally "terraform apply -auto-approve" to deploy.
