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
   Create file
   ```
   vi etc/sudoers.d/semaphore
   ```
   add in file
   ```
   semaphore ALL=(ALL) NOPASSWD: ALL
   ```