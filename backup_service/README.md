# Backup Service

Ansible playbooks for backing up Docker-based services on ubuntu-1.

All backups are stored on the server under:
```
/home/skogsparlan/backup/app_backup/<service>/
```

---

## Available Backup Playbooks

| Playbook | Service | What is backed up |
|---|---|---|
| `backup_paperless.yml` | Paperless-NGX + AI | DB dump, documents, index, AI data, .env |
| `backup_sonarr.yml` | Sonarr | Config + built-in backups |
| `backup_radarr.yml` | Radarr | Config + built-in backups |
| `backup_bazarr.yml` | Bazarr | Config |
| `backup_prowlarr.yml` | Prowlarr | Config |
| `backup_readarr.yml` | Readarr | Config |
| `backup_photoprism.yml` | Photoprism | Config + storage |
| `backup_nzbget.yml` | NZBGet | Config |
| `backup_qbittorrent.yml` | qBittorrent | Config |

---

## Running a Backup

```bash
ansible-playbook -i inventory/semaphore_inventory.yml.local \
  backup_service/backup_<service>.yml
```

Example — Paperless:
```bash
ansible-playbook -i inventory/semaphore_inventory.yml.local \
  backup_service/backup_paperless.yml
```

Each run creates a **timestamped sub-directory** so multiple backups are retained:
```
/home/skogsparlan/backup/app_backup/paperless/
├── 2026-04-09_1430/
│   ├── paperless_db.dump       ← PostgreSQL compressed dump
│   ├── media/                  ← processed documents
│   ├── data/                   ← search index, thumbnails
│   ├── export/                 ← manual exports
│   ├── paperless-ai-data/      ← AI config and RAG index
│   └── .env                    ← stack secrets (mode 0600)
└── 2026-04-10_0200/
    └── ...
```

---

## Paperless — Detailed Backup & Restore

### What Each Directory Contains

| Directory | Contents | Restore priority |
|---|---|---|
| `paperless_db.dump` | All metadata: tags, correspondents, document records | 🔴 Critical |
| `media/` | The actual document files (PDFs, images) | 🔴 Critical |
| `data/` | Search index, thumbnails, ML classifiers | 🟡 Important |
| `export/` | Manual exports | 🟢 Optional |
| `paperless-ai-data/` | Paperless-AI config and RAG index | 🟡 Important |
| `.env` | Stack secrets and configuration | 🔴 Critical |

### Backup Process (what the playbook does)

1. Stops `paperless_ai` container (prevents writes during snapshot)
2. Runs `pg_dump` inside the `paperless_db` container → compressed binary dump
3. Copies the dump file out of the container
4. Copies all data directories to the timestamped backup location
5. Copies `.env` with restricted permissions (mode 0600)
6. Restarts `paperless_ai`

> **paperless-ngx stays running during backup** — no downtime for document access.

---

### Restore Procedure

> ⚠️ Stop the stack before restoring to avoid data conflicts.

#### 1. Stop the stack

```bash
cd /home/ansible/repos/Ansible_playbooks_ubuntu_server/docker/paperless
docker compose down
```

#### 2. Restore .env

```bash
cp /home/skogsparlan/backup/app_backup/paperless/<TIMESTAMP>/.env \
   /home/hugo/paperless/.env
chmod 600 /home/hugo/paperless/.env
```

#### 3. Restore document files

```bash
# Replace <TIMESTAMP> with the directory you want to restore from
BACKUP=/home/skogsparlan/backup/app_backup/paperless/<TIMESTAMP>

rsync -av --delete "$BACKUP/media/"         /home/hugo/paperless/media/
rsync -av --delete "$BACKUP/data/"          /home/hugo/paperless/data/
rsync -av --delete "$BACKUP/export/"        /home/hugo/paperless/export/
rsync -av --delete "$BACKUP/paperless-ai-data/" /home/hugo/paperless/paperless-ai-data/
```

#### 4. Start the database only and restore the dump

```bash
cd /home/ansible/repos/Ansible_playbooks_ubuntu_server/docker/paperless
docker compose up -d paperless_db
sleep 10  # wait for postgres to be ready

BACKUP=/home/skogsparlan/backup/app_backup/paperless/<TIMESTAMP>

# Copy dump into container
docker cp "$BACKUP/paperless_db.dump" paperless_db:/tmp/paperless_db.dump

# Drop and recreate the database, then restore
docker exec paperless_db psql -U paperless -c "DROP DATABASE IF EXISTS paperless;"
docker exec paperless_db psql -U paperless -c "CREATE DATABASE paperless;"
docker exec paperless_db pg_restore -U paperless -d paperless /tmp/paperless_db.dump

# Clean up
docker exec paperless_db rm /tmp/paperless_db.dump
```

#### 5. Start the full stack

```bash
docker compose up -d
```

#### 6. Verify

- Open **http://192.168.0.111:8010** — documents and tags should be present
- Open **http://192.168.0.111:3000** — Paperless-AI should reconnect

---

## Listing & Managing Backups

```bash
# List all paperless backups with sizes
du -sh /home/skogsparlan/backup/app_backup/paperless/*/

# Remove a specific old backup
rm -rf /home/skogsparlan/backup/app_backup/paperless/<TIMESTAMP>
```

---

## Scheduling Automated Backups (Semaphore)

Add `backup_service/backup_paperless.yml` as a scheduled task in Semaphore:

- **Schedule**: daily (e.g. `0 2 * * *` — 02:00 AM)
- **Inventory**: `semaphore_inventory.yml.local`
- **Playbook**: `backup_service/backup_paperless.yml`

Retention: manually remove old timestamped directories as needed,
or add a cleanup task to delete backups older than N days:

```bash
find /home/skogsparlan/backup/app_backup/paperless/ \
  -maxdepth 1 -type d -mtime +30 -exec rm -rf {} \;
```
