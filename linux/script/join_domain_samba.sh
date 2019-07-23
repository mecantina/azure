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
export DEBIAN_FRONTEND=noninteractive
apt -yq install krb5-user samba sssd chrony ntpdate ntp libsss-sudo heimdal-clients
apt -yq install libsss-sudo
# Configure NTP
systemctl stop ntp  
echo "pool $domainToJoin " >/etc/ntp.conf
systemctl start ntp 
ntpdate -u a-e.no && hwclock -w 
timedatectl set-timezone Europe/Oslo
echo "NTP and timezone updated, local time: $(date)" >>/var/log/jdlog

# Configure Kerberos
echo "[libdefaults]" > /etc/krb5.conf 
echo "  default_realm = $realmName" >>etc/krb5.conf 
echo "  ticket_lifetime = 24h" >>etc/krb5.conf
echo "  renew_lifetime = 7d" >>etc/krb5.conf
echo "  kdc_timesync = 1" >>etc/krb5.conf
echo "  ccache_type = 4" >>etc/krb5.conf
echo "  forwardable = true" >>etc/krb5.conf
echo "  proxiable = true" >>etc/krb5.conf
echo "  fcc-mit-ticketflags = true" >>etc/krb5.conf
echo "Kerberos configured:" >>/var/log/jdlog
cat /etc/krbr5.conf >>/var/log/jdlog

# Configure Chrony
echo "server $domainToJoin" >/etc/chrony/chrony.conf
echo "keyfile /etc/chrony/chrony.keys" >>/etc/chrony/chrony.conf
echo "driftfile /var/lib/chrony/chrony.drift" >>/etc/chrony/chrony.conf
echo "logdir /var/log/chrony" >>/etc/chrony/chrony.conf
echo "maxupdateskew 100.0" >>/etc/chrony/chrony.conf
echo "rtcsync" >>/etc/chrony/chrony.conf
echo "makestep 1 3" >>/etc/chrony/chrony.conf
echo "Chrony configured: " >>/var/log/jdlog
cat /etc/chrony/chrony.conf >>/var/log/jdlog

# Configure Samba
echo "[global]" > /etc/samba/smb.conf
echo "  workgroup = $netbiosName" >> /etc/samba/smb.conf
echo "  client signing = yes" >> /etc/samba/smb.conf
echo "  client use spnego = yes" >> /etc/samba/smb.conf
echo "  kerberos method = secrets and keytab" >> /etc/samba/smb.conf
echo "  realm = $realmName" >> /etc/samba/smb.conf
echo "  security = ads" >> /etc/samba/smb.conf
echo " " >> /etc/samba/smb.conf
echo "  server string = %h server (Samba, Ubuntu)" >> /etc/samba/smb.conf
echo " " >> /etc/samba/smb.conf
echo "  dns proxy = no" >> /etc/samba/smb.conf
echo " " >> /etc/samba/smb.conf
echo "  log file = /var/log/samba/log.%m" >> /etc/samba/smb.conf
echo "  log level = 3" >> /etc/samba/smb.conf
echo "  max log size = 1000" >> /etc/samba/smb.conf
echo "  syslog = 0" >> /etc/samba/smb.conf
echo "  panic action = /usr/share/samba/panic-action %d" >> /etc/samba/smb.conf
echo " " >> /etc/samba/smb.conf
echo "  server role = standalone server" >> /etc/samba/smb.conf
echo "  passdb backend = tdbsam" >> /etc/samba/smb.conf
echo "  obey pam restrictions = yes" >> /etc/samba/smb.conf
echo "  unix password sync = yes" >> /etc/samba/smb.conf
echo "  passwd program = /usr/bin/passwd %u" >> /etc/samba/smb.conf
echo "  passwd chat = *Enter\snew\s*\spassword:* %n\n *Retype\snew\s*\spassword:* %n\n *password\supdated\ssuccessfully* ." >> /etc/samba/smb.conf
echo "  pam password change = yes" >> /etc/samba/smb.conf
echo "  map to guest = bad user" >> /etc/samba/smb.conf
echo " " >> /etc/samba/smb.conf
echo "   usershare allow guests = yes" >> /etc/samba/smb.conf
echo " " >> /etc/samba/smb.conf
echo "[homes]" >> /etc/samba/smb.conf 
echo "  comment = Home Directories" >> /etc/samba/smb.conf
echo "  browseable = no" >> /etc/samba/smb.conf
echo "  read only = no" >> /etc/samba/smb.conf
echo "  create mask = 0700" >> /etc/samba/smb.conf
echo "  valid users = %S" >> /etc/samba/smb.conf
echo " " >> /etc/samba/smb.conf
echo "load printers = no" >> /etc/samba/smb.conf
echo "cups options = raw" >> /etc/samba/smb.conf
echo "printcap name = /dev/null" >> /etc/samba/smb.conf
echo "" >> /etc/samba/smb.conf
echo "Samba configured:" >>/var/log/jdlog
cat /etc/samba/smb.conf >>/var/log/jdlog

# Configure sssd
echo "[sssd]" >/etc/sssd/sssd.conf
echo "services = nss, pam" >>/etc/sssd/sssd.conf
echo "config_file_version = 2" >>/etc/sssd/sssd.conf
echo "domains = $realmName" >>/etc/sssd/sssd.conf
echo " " >>/etc/sssd/sssd.conf
echo "[domain/$realmName]" >>/etc/sssd/sssd.conf
echo "id_provider = ad" >>/etc/sssd/sssd.conf
echo "access_provider = ad" >>/etc/sssd/sssd.conf
echo " " >>/etc/sssd/sssd.conf
echo "# Use this if users are being logged in at /." >>/etc/sssd/sssd.conf
echo "# This example specifies /home/DOMAIN-FQDN/user as $HOME.  Use with pam_mkhomedir.so" >>/etc/sssd/sssd.conf
echo "override_homedir = /home/%u" >>/etc/sssd/sssd.conf
echo " " >>/etc/sssd/sssd.conf
echo "# Uncomment if the client machine hostname doesn't match the computer object on the DC." >>/etc/sssd/sssd.conf
echo "# ad_hostname = mymachine.myubuntu.example.com" >>/etc/sssd/sssd.conf
echo " " >>/etc/sssd/sssd.conf
echo "# Uncomment if DNS SRV resolution is not working " >>/etc/sssd/sssd.conf
echo "ad_server = $domainToJoin" >>/etc/sssd/sssd.conf
echo " " >>/etc/sssd/sssd.conf
echo "# Uncomment if the AD domain is named differently than the Samba domain" >>/etc/sssd/sssd.conf
echo "# ad_domain = $realmName" >>/etc/sssd/sssd.conf
echo " " >>/etc/sssd/sssd.conf
echo "# Enumeration is discouraged for performance reasons." >>/etc/sssd/sssd.conf
echo "enumerate = false" >>/etc/sssd/sssd.conf
echo "SSSD configured:" >>/var/log/jdlog
chown root:root /etc/sssd/sssd.conf
sudo chmod 600 /etc/sssd/sssd.conf
cat /etc/sssd/sssd.conf >>/var/log/jdlog

# Configure nsswitch.conf
echo "passwd:         compat sss" >/etc/nsswitch.conf
echo "group:          compat sss" >>/etc/nsswitch.conf
echo "shadow:         compat sss" >>/etc/nsswitch.conf
echo "gshadow:        files" >>/etc/nsswitch.conf
echo " " >>/etc/nsswitch.conf
echo "hosts:          files dns" >>/etc/nsswitch.conf
echo "networks:       files" >>/etc/nsswitch.conf
echo " " >>/etc/nsswitch.conf
echo "protocols:      db files" >>/etc/nsswitch.conf
echo "services:       db files sss" >>/etc/nsswitch.conf
echo "ethers:         db files" >>/etc/nsswitch.conf
echo "rpc:            db files" >>/etc/nsswitch.conf
echo " " >>/etc/nsswitch.conf
echo "netgroup:       nis sss" >>/etc/nsswitch.conf
echo "sudoers:        files sss" >>/etc/nsswitch.conf
echo "nsswitch configured:"
cat /etc/nsswitch.conf >>/var/log/jdlog

# Configure /etc/hosts
ipAddress = $(hostname --ip-address)
echo "$ipAddress $fullVmName $fullVmName.$domainToJoin" >>/etc/hosts 
echo "Hosts configures:"
cat /etc/hosts >>/var/log/jdlog 

# Configure auto home dir
echo "session required        pam_mkhomedir.so        skel=/etc/skel/ umask=0022" >>/etc/pam.d/common-session
echo "Common-session configured: " >>/var/log/jdlog
cat /etc/pam.d/common-session >>/var/log/jdlog

# Restart services
echo "Restarting services..." >>/var/log/jdlog
systemctl restart chrony.service
systemctl restart smbd.service nmbd.service
systemctl start sssd.service

echo "kinit..." >>/var/log/jdlog
echo $domainPassword | kinit $domainUsername
klist >>/var/log/jdlog
echo "Joining domain..." >>/var/log/jdlog
net ads join -k createcomputer="$ouPath" >>/var/log/jdlog
echo "Done" >>/var/log/jdlog