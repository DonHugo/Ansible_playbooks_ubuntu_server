# Server setup
## 1. Installera virtualmin
[virtualmin](https://www.virtualmin.com/download/)
## 2. Installera ansible
```
sudo apt update
sudo apt install software-properties-common
sudo add-apt-repository --yes --update ppa:ansible/ansible
sudo apt install ansible
```

## 3. add user semaphore
```
cat << 'EOF' > setup_user_semaphore.sh
#!/bin/bash

# Prompt for semaphore user password
read -sp "Enter password for semaphore user: " semaphore_password
echo

# Create user semaphore with the provided password
sudo useradd -m semaphore
echo "semaphore:$semaphore_password" | sudo chpasswd

# Create the sudoers file for semaphore
echo "semaphore ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/semaphore

# Change the permissions on the sudoers file
sudo chmod 440 /etc/sudoers.d/semaphore

# Add SSH keys to semaphore's authorized_keys
sudo -u semaphore mkdir -p /home/semaphore/.ssh
echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJy9ToRyqiaTxYpEfCKdQ+cLaLgzGCGuuuLiMHmOp4sV" | sudo tee -a /home/semaphore/.ssh/authorized_keys
echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEMTk0d/AOl8g5UmzGjO0ih7tEbUbnaz7Zflk3/SoY1D" | sudo tee -a /home/semaphore/.ssh/authorized_keys
sudo chown semaphore:semaphore /home/semaphore/.ssh/authorized_keys
sudo chmod 600 /home/semaphore/.ssh/authorized_keys

# Prompt for current user password
read -sp "Enter new password for current user ($USER): " current_user_password
echo
echo "$USER:$current_user_password" | sudo chpasswd

echo "User semaphore created, sudoers file configured, SSH keys added to authorized_keys, id_ed25519 keys moved, ssh reloaded, and current user password changed."
EOF

chmod +x setup_user_semaphore.sh
sudo ./setup_user_semaphore.sh
```

