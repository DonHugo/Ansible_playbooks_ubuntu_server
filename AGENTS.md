# Ansible Playbooks Multi-Agent System

This repository uses a 7-agent system for DevOps automation and infrastructure management.

## Agent Roles

### Orchestration Layer
- **@manager** - Project coordination and deployment orchestration
- **@coach** - Workflow optimization and DevOps best practices

### Execution Layer  
- **@requirements** - Infrastructure requirements and service specifications
- **@architect** - System architecture and deployment design
- **@tester** - Playbook testing and validation strategies
- **@developer** - Ansible playbook implementation and Docker compose files
- **@validator** - Production validation and infrastructure testing

## Commands

### Running Playbooks
```bash
# Run specific playbook
ansible-playbook -i inventory/semaphore_inventory.yml.local <playbook-file>

# Test connectivity
ansible all -i inventory/semaphore_inventory.yml.local -m ping

# Run with verbose output
ansible-playbook -i inventory/semaphore_inventory.yml.local <playbook> -v

# Dry run (check mode)
ansible-playbook -i inventory/semaphore_inventory.yml.local <playbook> --check
```

### Linting/Validation
```bash
# Check playbook syntax
ansible-playbook --syntax-check <playbook-file>

# Validate YAML
ansible-playbook --check <playbook-file>

# Run specific test playbook
ansible-playbook -i inventory/semaphore_inventory.yml.local tests/test_<service>.yml
```

## Code Style Guidelines

### File Structure
- Use descriptive filenames with underscores: `deploy_jellyfin.yml`, `backup_sonarr.yml`
- Group related playbooks in directories: `deploy_docker_service/`, `backup_service/`
- Keep Docker compose files in `docker/` subdirectory matching service name
- Test playbooks in `tests/` directory with `test_` prefix

### Ansible Conventions
- Always specify `become: yes` for privileged operations
- Use `hosts: all` for general operations, specific hosts when needed
- Use `ansible.builtin.` module prefix for core modules
- Use `community.docker.` for Docker-related modules
- Create directories before using them with `file` module and `state: directory`
- Set proper ownership (`owner: hugo`, `group: hugo`) and permissions (`mode: 0775`)
- Use `register: output` for task results and `failed_when:` for error handling

### YAML Formatting
- Use 2-space indentation
- Include comments for complex operations
- Register task output with descriptive names: `register: output`
- Use loops with `loop:` and item variables
- Use `when:` conditions for conditional execution

### Security
- Never commit sensitive data (IPs, passwords, SSH keys)
- Use inventory files in `inventory/` directory (gitignored)
- Reference external repositories with HTTPS URLs when possible
- Use Ansible Vault for secrets when needed

## Multi-Agent Workflow

1. **@requirements** defines infrastructure needs
2. **@architect** designs deployment strategy  
3. **@tester** creates validation playbooks
4. **@developer** implements playbooks and compose files
5. **@validator** runs production validation
6. **@manager** coordinates deployment sequence
7. **@coach** optimizes DevOps processes