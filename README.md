# cptdgrafana

## Grafana on Azure VM

Based on https://yallalabs.com/linux/how-to-install-grafana-using-mysql-mariadb-database-on-centos-7-rhel-7/ 

### Define env variables

~~~ bash
prefix=cptdgrafana
myip=$(curl ifconfig.io)
myobjectid=$(az ad user list --query '[?displayName==`ga`].objectId' -o tsv)
~~~

### Create Azure resources

~~~ bash
az group delete -n $prefix -y
az group create -n $prefix -l eastus
az deployment group create -n $prefix -g $prefix --template-file bicep/deploy.bicep -p myobjectid=$myobjectid myip=$myip prefix=$prefix
~~~

### SSH into grafana VM via azure bastion client

> IMPORTANT: The following commands need to executed on powershell.

~~~ pwsh
$prefix="cptdgrafana"
$vmid=az vm show -g $prefix -n ${prefix}grafana --query id -o tsv
az network bastion ssh -n ${prefix}bastion -g $prefix --target-resource-id $vmid --auth-type "AAD"
~~~

Inside the vm execute the following commands to get some insights about the current state of your grafana installation.

~~~ bash
sudo -i
systemctl status grafana-server
nano /etc/grafana/grafana.ini //verify grafana configuration
grep "^[^#\[;]" -B 5 -A 5 /etc/grafana/grafana.ini //find all active settings
tail -f /var/log/grafana/grafana.log //verify grafana server logs
systemctl restart grafana-server
nano /usr/lib/systemd/system/grafana-server.service //Grafana Service settings
nano /etc/default/grafana-server //ENV Variable Definition
~~~

### RDP into win VM via azure bastion client

> IMPORTANT: The following commands need to executed on powershell.

To see grafana in action we did also setup a windows client which will be used to test the grafana portal.

~~~ pwsh
$prefix="cptdgrafana"
$vmidwin=az vm show -g $prefix -n ${prefix}win --query id -o tsv
az network bastion rdp -n ${prefix}bastion -g ${prefix} --target-resource-id $vmidwin
~~~

### SSH into nodejs VM via azure bastion client

> IMPORTANT: The following commands need to executed on powershell.

We did also setup a node.js application which can be used to feed data into grafana.

~~~ pwsh
$prefix="cptdgrafana"
$vmidnodejs=az vm show -g $prefix -n ${prefix}nodejs --query id -o tsv
az network bastion ssh -n ${prefix}bastion -g $prefix --target-resource-id $vmidnodejs --auth-type "AAD"
~~~

### Setup MQTT Server

~~~ bash
mosquitto_passwd -b /etc/mosquitto/passwd chpinoto 'demo!pass123'
mosquitto_sub -L 'mqtt://chpinoto:demo!pass123@10.0.0.4:1883/cptdgrafana/#' -d
mosquitto_pub -L 'mqtt://chpinoto:demo!pass123@10.0.0.4:1883/cptdgrafana/test' -m 'hello2'
mosquitto_pub -L 'mqtt://chpinoto:demo!pass123@10.0.0.4:1883/cptdgrafana/test' -m 'hello2' -d
systemctl start mosquitto.service
systemctl status mosquitto.service
nano /etc/mosquitto/conf.d/myconfig.conf
nano /etc/mosquitto/acl
nano /etc/mosquitto/conf.d/myconfig.conf
netstat -tulpn | grep 1883
~~~

## TODO
- Finish Setup of MQTT Broker
- Extend the node.js App to feed MQTT messages into Grafana.
- Need to fix the deploy twice, first deployment does present the message ""SubscriptionDoesNotHaveServer\\\",\\r\\n        \\\"message\\\": \\\"Subscription '---' does not have the server 'cptdgrafana'. "

# Misc

## Azure Blob Storage

### Mount the blob storage container

Inside the vm execute the following commands.

~~~ pwsh
$prefix="cptdgrafana"
$vmid=az vm show -g $prefix -n ${prefix}grafana --query id -o tsv
az network bastion ssh -n ${prefix}bastion -g $prefix --target-resource-id $vmid --auth-type "AAD"
sudo -i
apt install nfs-common -y
prefix=cptdgrafana
mkdir -p /mnt/test
mount -o sec=sys,vers=3,nolock,proto=tcp ${prefix}.blob.core.windows.net:/${prefix}/${prefix}  /mnt/test
ls /mnt/test/
chgrp -R chpinoto /mnt/test/
chmod 777 /mnt/test/
~~~

## Get the IP of the k8s service

~~~ text
k get services/svred  -n nsred -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
~~~

## MySQL

### Install MySQL CLI

Install instruction based on https://dev.mysql.com/doc/mysql-shell/8.0/en/mysql-shell-install-linux-quick.html

~~~ text
sudo -i
apt-get update
apt install mysql-client-core-5.7 -y
~~~

### Create MySql User and Grants 

Based on https://docs.microsoft.com/en-us/azure/mysql/howto-create-users

~~~ bash
mysql -h cptdgrafana.mysql.database.azure.com -u chpinoto@cptdgrafana -p'demo!pass123'
CREATE USER chpinoto@cptdgrafana IDENTIFIED BY "demo!pass123";
GRANT ALL PRIVILEGES ON grafana.* TO chpinoto@cptdgrafana;
exit
~~~


### How to List MySQL User Account-Privileges
Based on https://phoenixnap.com/kb/how-to-create-new-mysql-user-account-grant-privileges
To display all the current privileges held by a user:

~~~ text
mysql -h cptdgrafana.mysql.database.azure.com -u chpinoto@cptdgrafana -p'demo!pass123'
SHOW GRANTS FOR chpinoto;
~~~

### List tables

~~~ text
mysql -h cptdgrafana.mysql.database.azure.com -u chpinoto@cptdgrafana -p'demo!pass123'
CREATE DATABASE cptdgrafana;
SHOW DATABASES;
USE cptdgrafana;
SHOW TABLES;
SHOW FULL TABLES;
USE grafana;
~~~

## Grafana

### Setup Grafana via Env Variables

- https://grafana.com/docs/grafana/latest/administration/configuration/#database

## How to delete VM and all resources

> NOTE: You will need to have setup the property "deleteOption: 'Delete'" inside the vm resource subresources nic and os-storage.

~~~ text
az vm list -g $prefix -o table
az vm delete -g $prefix -n ${prefix}grafana -y
az vm delete -g $prefix -n ${prefix}nodejs -y
az vm delete -g $prefix -n ${prefix}mqtt -y
~~~

## Ubuntu

~~~ text
awk -F: '{ print $1}' /etc/passwd //list all users
sudo -Hiu grafana env
su - grafana -c 'echo $PATH'
~~~

### App to monitor with Grafana

~~~ text
cd nodejs
npm install
npm run start
curl -k "https://localhost:4040"
curl "http://localhost:8080"
cd ..
~~~

## AzCopy

~~~ text
azcopy cp "grafana/grafana.ini" "https://${prefix}.blob.core.windows.net/${prefix}/grafanatest1.txt"

## Git

~~~ text
git init master
gh repo create cptdgrafana --public
git remote add origin https://github.com/cpinotossi/cptdgrafana.git
git status
git commit -m""
git push origin master

git tag //list local repo tags
git ls-remote --tags origin //list remote repo tags
git fetch --all --tags // get all remote tags into my local repo
git log --oneline --decorate // List commits
git log --pretty=oneline //list commits
git tag -a v2 b20e80a //tag my last commit

git checkout v1
git switch - //switch back to current version
co //Push all my local tags
git push origin <tagname> //Push a specific tag
git commit -m"not transient"
git tag v1
git push origin v1
git tag -l
git fetch --tags
git clone -b <git-tagname> <repository-url> 
~~~

