#!/bin/bash
#
# Join a computer to the Active Directory domain
#
fullVmName=$1               # Name of VM
domainToJoin="$2"           # Full name of domain to join, e.g. mycompany.com
dnsDiscoveryDomain="$3"     # Uppercase domainname, e.g. MYCOMPANY.com
ouPath="$4"                 # Computer OU path in AD, e.g. OU=Linux, OU=Computers, DC=Mycompany, DC=com
domainUsername="$5"         # Username authorized in AD to be allowed to join the domain
domainPassword="$6"         # Password to authenticate domainUsername
allowedLoginGroups="$7"     # Space-separated list of AD groups that will be allowed to login to the server and given sudo rights
realmName="$8"              # All uppercase domain, e.g. MYCOMPANY.COM
netbiosName="$9"            # Pre-Win2K domain name

# Log request parameters
echo "Join_domain was here!" >/var/log/jdlog
echo " Full VM Name: $fullVmName" >>/var/log/jdlog
echo " Domain to join: $domainToJoin" >>/var/log/jdlog
echo " DNS Discovery domain: $dnsDiscoveryDomain" >>/var/log/jdlog
echo " OU Path: $ouPath" >>/var/log/jdlog
echo " Domain Username: $domainUsername" >>/var/log/jdlog
echo " Netbios Name: $netbiosName" >>/var/log/jdlog
echo " Realmname: $realmName" >>/var/log/jdlog

# Install packages
apt -y install realmd sssd sssd-tools libnss-sss libpam-sss adcli samba-common-bin oddjob oddjob-mkhomedir packagekit samba winbind ntp ntpdate
echo "Software install done" >>/var/log/jdlog

# Configure NTP
systemctl stop ntp  
echo "pool $domainToJoin " >/etc/ntp.conf
systemctl start ntp 
ntpdate -u a-e.no && hwclock -w 
timedatectl set-timezone Europe/Oslo
echo "NTP and timezone updated, local time: $(date)" >>/var/log/jdlog

# Join domain
echo $domainPassword | realm join $domainToJoin -U $domainUsername --computer-ou="$ouPath"
echo "Domain joined" >>/var/log/jdlog
realm list >>/var/log/jdlog

# Configure pam.d
echo "session required pam_mkhomedir.so skel=/etc/skel/ umask=0022" >>/etc/pam.d/common-session
echo "/etc/pam.d/common-session updated" >>/var/log/jdlog

# Configure sssd
sed -i 's/use_fully_qualified_names = True/use_fully_qualified_names = False/g' /etc/sssd/sssd.conf
sed -i 's+fallback_homedir = /home/%u@%d+fallback_homedir = /home/%u+g' /etc/sssd/sssd.conf
echo "ad_server = $domainToJoin" >>/etc/sssd/sssd.conf
echo "dns_discovery_domain = $dnsDiscoveryDomain" >>/etc/sssd/sssd.conf
echo "dyndns_update = true" >>/etc/sssd/sssd.conf
echo "dyndns_refresh_intervcal = 43200" >>/etc/sssd/sssd.conf
echo "dyndns_update_ptr = true" >>/etc/sssd/sssd.conf
echo "dyndns_ttl = 3600" >>/etc/sssd/sssd.conf
echo "sssd updated" >>/var/log/jdlog

# Configure permits
realm deny --all        # No domain logins allowed per default
for group in $allowedLoginGroups; do
    echo "  Permitting login for group $group.$domainToJoin" >>/var/log/jdlog
    realm permit --groups $group $domainToJoin
    echo "  Adding group $group to /etc/sudoers" >>/var/log/jdlog
    echo "%$group ALL=(ALL:ALL) ALL" >>/etc/sudoers
done

systemctl restart sssd >>/var/log/jdlog
echo "Realm permit executed" >>/var/log/jdlog

# Configure Samba
# sed -i "s/   workgroup = WORKGROUP/   workgroup = $netbiosName/g" /etc/samba/smb.conf
# Backup default sambaconfig
cp /etc/samba/smb.conf /root
# Create new config
echo "[global]" > /etc/samba/smb.conf
echo "workgroup = $netbiosName" >> /etc/samba/smb.conf
echo "server string = Samba Server version %v" >> /etc/samba/smb.conf
echo "host allow 127. 172.230. 172.17." >> /etc/samba/smb.conf
echo "log file = /var/log/samba/log.%m" >> /etc/samba/smb.conf
echo "log level = 3" >> /etc/samba/smb.conf
echo "max log size = 1000" >> /etc/samba/smb.conf
echo " " >> /etc/samba/smb.conf
echo "security = ads" >> /etc/samba/smb.conf
echo "encrypt passwords = yes" >> /etc/samba/smb.conf
echo "passdb backend = tdbsam" >> /etc/samba/smb.conf
echo "realm = $realmName" >> /etc/samba/smb.conf
echo " " >> /etc/samba/smb.conf
echo "load printers = no" >> /etc/samba/smb.conf
echo "cups options = raw" >> /etc/samba/smb.conf
echo "printcap name = /dev/null" >> /etc/samba/smb.conf
echo "" >> /etc/samba/smb.conf
echo "Samba configured" >>/var/log/jdlog

exit 0