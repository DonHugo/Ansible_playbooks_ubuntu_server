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
   sudo as root

   ```
   sudo -i
   ```

   Create file
   ```
   cd /etc/sudoers.d/
   vi semaphore
   ```
   
   add in file
   ```
   semaphore ALL=(ALL) NOPASSWD: ALL
   ```
   
   Change permisson on file
   ```
   chmod 440 semaphore
   ```

