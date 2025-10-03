# Ansible Playbooks Ubuntu Server

Collection of Ansible playbooks for Ubuntu server management, Docker services, and NFS setup.

## Quick Start

1. **Clone the repository**
   ```bash
   git clone https://github.com/DonHugo/Ansible_playbooks_ubuntu_server.git
   cd Ansible_playbooks_ubuntu_server
   ```

2. **Set up your inventory**
   ```bash
   cp inventory/example_inventory.yml inventory/semaphore_inventory.yml.local
   # Edit inventory/semaphore_inventory.yml.local with your actual server details
   ```

3. **Configure SSH keys**
   ```bash
   # Ensure your SSH keys are set up for passwordless access
   ssh-copy-id user@your-server-ip
   ```

4. **Test connectivity**
   ```bash
   ansible ubuntu_servers -i inventory/semaphore_inventory.yml.local -m ping
   ```

## Project Structure

```
├── ansible_basic_setup/          # Initial server setup
├── deploy_docker_service/       # Service deployments  
├── backup_service/              # Backup operations
├── tear_down_service/          # Cleanup operations
├── nfs_project/                # NFS infrastructure
├── docker/                     # Docker compose files
└── inventory/                  # Ansible inventory files
```

## Usage with Semaphore

This project is designed to work with [Semaphore](https://github.com/ansible-semaphore/semaphore) for Ansible automation.

### Inventory Setup

1. Copy the example inventory: `cp inventory/example_inventory.yml inventory/semaphore_inventory.yml.local`
2. Update with your actual server IPs and credentials
3. Import the inventory file into Semaphore

### Playbook Categories

- **Initial Setup**: `ansible_basic_setup/initial.yml`
- **Docker Services**: `deploy_docker_service/deploy_*.yml`
- **Backup Operations**: `backup_service/backup_*.yml`
- **NFS Setup**: `nfs_project/setup_nfs_server.yml`

## Security Notes

- **Never commit sensitive information** like IP addresses, passwords, or SSH keys
- The `inventory/` directory is gitignored to protect your server details
- Use the example inventory as a template for your setup
- Store your actual inventory file as `semaphore_inventory.yml.local`

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test with your own servers
5. Submit a pull request

## License

This project is open source. Please ensure you don't commit sensitive information.