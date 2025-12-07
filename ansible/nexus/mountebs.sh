#!/bin/bash
sudo mkfs -t ext4 /dev/xvdf
sudo mkdir /nexus-ebs
sudo mount /dev/xvdf /nexus-ebs
echo "/dev/xvdf /nexus-ebs ext4 defaults,nofail 0 2" | sudo tee -a /etc/fstab

