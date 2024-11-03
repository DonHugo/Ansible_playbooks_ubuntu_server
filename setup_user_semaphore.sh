#!/bin/bash

# Create user semaphore
sudo useradd -m semaphore

# Create the sudoers file for semaphore
echo "semaphore ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/semaphore

# Change the permissions on the sudoers file
sudo chmod 440 /etc/sudoers.d/semaphore

# Add SSH key to semaphore's known_hosts
sudo -u semaphore mkdir -p /home/semaphore/.ssh
echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEMTk0d/AOl8g5UmzGjO0ih7tEbUbnaz7Zflk3/SoY1D" | sudo tee -a /home/semaphore/.ssh/known_hosts
sudo chown semaphore:semaphore /home/semaphore/.ssh/known_hosts
sudo chmod 644 /home/semaphore/.ssh/known_hosts

echo "User semaphore created, sudoers file configured, and SSH key added to known_hosts."