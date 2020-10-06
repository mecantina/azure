#!/bin/bash
#
# Install various Azure tools on the server:
#   Azure CLI
#   mssql tools
#   azcopy
#
LOGFILE=/var/log/atlog
echo "Install Azure tools was here" >$LOGFILE
#
# Azure CLI
#
echo "Install of Azure CLI started" >>$LOGFILE
apt -y install ca-certificates curl apt-transport-https lsb-release gnupg >>$LOGFILE
curl -sL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/microsoft.gpg > /dev/null
AZ_REPO=$(lsb_release -cs)
echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ $AZ_REPO main" | sudo tee /etc/apt/sources.list.d/azure-cli.list
apt -y update >>$LOGFILE
apt -y install azure-cli >>$LOGFILE
# 
# MSSQL tools
#
echo "Install of mssql tools started" >>$LOGFILE
curl https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add -
curl https://packages.microsoft.com/config/ubuntu/16.04/prod.list | sudo tee /etc/apt/sources.list.d/msprod.list
apt -y update >>$LOGFILE
apt -y install mssql-tools unixodbc-dev >>$LOGFILE
#
# azcopy
#
echo "Install of azcopy started" >>$LOGFILE
wget -O /usr/local/bin/azcopy https://raw.githubusercontent.com/mecantina/azure/master/linux/binary/azcopy 
chmod +x /usr/local/bin/azcopy
#
# Done
#
echo "Software install done" >>$LOGFILE