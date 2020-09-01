#!/bin/bash
#
# Create a LVM disk composed of several data disks
volumeName="$1"
mountPoint="$2" # Absolute mount point of the LVM disk
diskList="$3"   # Space-separated list of devices for the LVM
volumeGroupName="vg_$volumeName"

# Log request parameters
echo "Create LVM Disk started..." >>/var/log/lvmlog
echo "  Volume name:       $volumeName" >>/var/log/lvmlog
echo "  Volume Group name: $volumeGroupName" >>/var/log/lvmlog
echo "  MountPoint:        $mountPoint" >>/var/log/lvmlog
echo "  diskList:          $diskList" >>/var/log/lvmlog

# Install packages
apt -y update &>>/var/log/lvmlog
apt -y upgrade &>>/var/log/lvmlog
echo "Software install done" >>/var/log/lvmlog

# Create disk partitions
echo "Partitioning disks..." >>/var/log/lvmlog
for disk in "$diskList" 
do
    echo "  Partitioning $disk..." >>/var/log/lvmlog
    parted /dev/$disk mklabel gpt mkpart primary 2048s 100% >>/var/log/lvmlog
    partitionList="$partitionList /dev/$disk1"
done

echo "Partition list: $partitionList" >>/var/log/lvmlog

# Create Physical Volumes
echo "Creating Physical Volumes..." >>/var/log/lvmlog
pvcreate "$partitionList" >>/var/log/lvmlog

# Create Volume Group
echo "Creating Volume Group..." >>/var/log/lvmlog
vgcreate $volumeGroupName "$partitionList" >>/var/log/lvmlog

# Create Logical colume
echo "Creating Logical Volume..." >>/var/log/lvmlog
lvcreate -l 100%VG -n "$volumeName" "$volumeGroupName" >>/var/log/lvmlog

# Create file system
echo "Creating File System..." >>/var/log/lvmlog
mkfs.ext4 /dev/$volumeGroupName/$volumeName >>/var/log/lvmlog

echo "Mounting file system..." >>/var/log/lvmlog
echo "/dev/$volumeGroupName/$volumeName $mountPoint ext4 defaults 0 0" >>/etc/fstab
cat /etc/fstab >>/var/log/lvmlog
mkdir "$mountPoint" >>/var/log/lvmlog
mount -a >>/var/log/lvmlog

exit 0