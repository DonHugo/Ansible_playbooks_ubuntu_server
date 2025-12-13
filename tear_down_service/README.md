# Tear Down Service Playbooks

This directory contains Ansible playbooks for tearing down (stopping and removing) Docker containers managed by docker-compose.

## Available Tear Down Playbooks

- `tear_down_bazarr.yml` - Tear down Bazarr service
- `tear_down_jellyfin.yml` - Tear down Jellyfin service
- `tear_down_plex.yml` - Tear down Plex service
- `tear_down_stash.yml` - Tear down Stash service

## Usage

### Via Semaphore UI

#### Creating a Tear Down Template in Semaphore

1. **Navigate to Templates**
   - Go to your Semaphore project
   - Click on "Task Templates" in the left menu

2. **Create New Template**
   - Click "New Template" button
   - Fill in the following details:

   **Template Name:** `Teardown_stash_app`
   
   **Playbook Filename:** `tear_down_service/tear_down_stash.yml`
   
   **Inventory:** Select your inventory (e.g., `semaphore_inventory.yml.local`)
   
   **Repository:** Select your repository (e.g., `Ansible_playbooks_ubuntu_server`)
   
   **Environment:** Select your environment (if applicable)
   
   **Extra Variables:** (leave empty or add as needed)
   
   **Vault Password:** (if you use Ansible Vault)

3. **Save Template**
   - Click "Create" to save the template

4. **Run the Tear Down**
   - Go to "Tasks" in the left menu
   - Click "New Task"
   - Select the "Teardown_stash_app" template
   - Click "Run"
   - Monitor the output

### Via Command Line

```bash
# SSH into your Ansible control node or run locally
ansible-playbook -i inventory/semaphore_inventory.yml.local tear_down_service/tear_down_stash.yml
```

## What Tear Down Does

The tear down playbooks will:

✅ **Stop** the running Docker container(s)  
✅ **Remove** the container(s)  
✅ **Clean up** Docker resources associated with the compose project  
⚠️ **Preserve** all host-mounted volumes and data (e.g., `/home/hugo/stash/`)

## Typical Workflow

### When to Use Tear Down

Use tear down playbooks when you need to:

1. **Redeploy with configuration changes** - Remove old container before deploying new one
2. **Troubleshoot deployment issues** - Clean slate for fresh deployment
3. **Upgrade to new image version** - Remove old container to force image pull
4. **Perform maintenance** - Temporarily remove service

### Recommended Sequence

1. **First:** Run the tear down playbook
   - Example: Run `Teardown_stash_app` template in Semaphore
   - Wait for completion (should be quick, 10-20 seconds)

2. **Second:** Run the deploy playbook
   - Example: Run `Deploy_stash_app` template in Semaphore
   - Wait for completion and verify service is running

## Data Safety

### What is Preserved

- ✅ All configuration files in `/home/hugo/[service]/config/`
- ✅ All metadata in `/home/hugo/[service]/metadata/`
- ✅ All cache in `/home/hugo/[service]/cache/`
- ✅ All generated content in `/home/hugo/[service]/generated/`
- ✅ All NFS-mounted media (e.g., `/home/skogsparlan/`)
- ✅ Backups in `/home/skogsparlan/backup/app_backup/`

### What is Removed

- ⚠️ Docker container (can be recreated by deploy playbook)
- ⚠️ Container internal state (logs, temporary files inside container)
- ⚠️ Any unnamed Docker volumes (none in current configurations)

### Backup Recommendations

Before tearing down a service, ensure you have:

1. **Recent backups** of configuration directories
2. **Documented custom settings** that might not be in config files
3. **List of any manual container modifications** (if any were made)

## Troubleshooting

### Issue: Tear down fails with "No such container"

**Cause:** Container is already removed or was never created  
**Solution:** This is safe to ignore - proceed with deploy playbook

### Issue: Tear down fails with "Container is not running"

**Cause:** Container exists but is already stopped  
**Solution:** Tear down will still remove the stopped container - check for success

### Issue: Tear down hangs or times out

**Cause:** Container is stuck or unresponsive  
**Solution:** 
```bash
# Manually force stop and remove
docker stop -t 10 [container_name]
docker rm -f [container_name]
```

### Issue: "Project not found" error

**Cause:** Repository not cloned or docker-compose.yml file missing  
**Solution:** Verify repository path and ensure docker-compose.yml exists

## Module Information

All tear down playbooks use:
- **Module:** `community.docker.docker_compose_v2`
- **State:** `absent`
- **Requirements:** 
  - Ansible 2.10+
  - `community.docker` collection installed
  - Docker Compose V2 installed on target hosts

## Notes

- Tear down operations are **idempotent** - safe to run multiple times
- No data loss occurs from tearing down services (host volumes are preserved)
- Services can be immediately redeployed after tear down
- Tear down does NOT remove Docker images (they will be reused on next deploy)
