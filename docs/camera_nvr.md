# Kamera & NVR — go2rtc + Frigate

## Arkitekturöversikt

```
┌─────────────────────────┐         RTSP          ┌─────────────────────────┐
│ ubuntu_2                │ <ubuntu-2-IP>:8554    │ ubuntu_main             │
│                         │ ─────────────────────► │                         │
│ USB-kamera ─► go2rtc    │                        │ Frigate NVR             │
│ YUYV→H.264 + rotate 180 │                        │ OpenVINO på CPU         │
│                         │                        │          │              │
│ 8554/TCP                │                        │          ▼ MQTT         │
└─────────────────────────┘                        │ <HA-MQTT-IP>:1883       │
                                                   │                         │
                                                   │ 8971 UI, 8554 RTSP,    │
                                                   │ 8555 WebRTC            │
                                                   └─────────────────────────┘
```

## Versioner och OCI-digests

| Komponent | Version | OCI index digest |
|-----------|---------|------------------|
| go2rtc | 1.9.14 | `sha256:675c318b23c06fd862a61d262240c9a63436b4050d177ffc68a32710d9e05bae` |
| Frigate | 0.17.2 | `sha256:d4351369984d4a9e2a49ac59736f6490856a7ea11f7790040746d21496967010` |
| Frigate config | 0.17-0 | — |

## Värdar

| Värd | Roll | IP | OS | CPU | Docker |
|------|------|----|----|-----|--------|
| ubuntu_2 | go2rtc (kamera-capture + RTSP) | Inventory (`FRIGATE_USB_CAMERA_RTSP_URL`) | Ubuntu 24.04.4 amd64 | Intel i7-3770S | 29.3.1 |
| ubuntu_main | Frigate NVR | Inventory (`FRIGATE_BIND_ADDRESS`) | Ubuntu 24.04.4 amd64 | Intel i7-3770S | 27.5.1 |

## Kamera

- **Modell:** Microsoft LifeCam Studio (USB-ID `045e:0772`)
- **Stabil enhetssökväg:** `/dev/v4l/by-id/usb-Microsoft_Microsoft®_LifeCam_Studio_TM_-video-index0`
- **Format:** Saknar H.264. Erbjuder MJPEG och RAW (YUYV).
- **Konfigurerad upplösning:** 1280×720 YUYV, 10 fps
- **H.264-transcode:** Software (FFmpeg) på ubuntu_2
- **Bildkorrigering:** 180° rotation; YUYV används för att undvika lila MJPEG-ton

> **index1 är metadata** (ej capture-nod). Mappa **enbart index0**.

### Om kameran byts eller formaten ändras

1. Anslut ny kamera till ubuntu_2
2. Identifiera stabil sökväg: `ls -la /dev/v4l/by-id/`
3. Lista format: `v4l2-ctl --list-formats-ext -d /dev/v4l/by-id/<ny-sökväg>`
4. Om kameran stöder H.264 nativt, ändra go2rtc-strömmen till t.ex.
   `ffmpeg:device?video=/dev/video0&input_format=h264&video_size=1920x1080&framerate=30`
5. Uppdatera `docker/go2rtc/docker-compose.yml` device-path
6. Uppdatera `docker/go2rtc/go2rtc.yaml` stream
7. Uppdatera Frigate `detect` width/height/fps efter behov

## Portar

| Tjänst | Värd | Port | Protokoll | Syfte |
|--------|------|------|-----------|-------|
| go2rtc | ubuntu_2 | 8554 | TCP | RTSP-strömning |
| Frigate | ubuntu_main | 8971 | TCP | Web UI (auth) |
| Frigate | ubuntu_main | 8554 | TCP | Integrerad go2rtc RTSP |
| Frigate | ubuntu_main | 8555 | TCP/UDP | WebRTC |

> **Port 5000** (Frigate intern) publiceras **inte** — inget behov.
> **Port 1984/8555** på go2rtc publiceras **inte** — API/WebRTC behövs ej där.

## Lagring och retention

### Frigate media (`/home/hugo/frigate/media`)

| Typ | Retention | Beskrivning |
|-----|-----------|-------------|
| Continuous recording | 0 dagar | **Inaktiverat** |
| Motion recording | 0 dagar | **Inaktiverat** |
| Alert (person) | 7 dagar | Sparar video vid person-detektion |
| Detections | 0 dagar | **Inaktiverat** |
| Snapshots (person) | 7 dagar | JPEG-bilder vid detektion |

### Lagringsuppskattning

**Formel:**
```
Daglig lagring ≈ (genomsnittlig bitrate Mbps × 3600 s × event-timmar/dag) / 8 × 1 000 000
```

Med software H.264 och 1280×720 ligger bitrate typiskt på **1–3 Mbps** beroende
på scen-komplexitet. Vid enbart händelsedriven inspelning (inga kontinuerliga
strömmar) beror faktisk användning på antal och längd av person-detektioner.

**Indikativt exempel:**
- 2 Mbps genomsnitt, 2 timmars händelser/dag → ~1.8 GB/dag → ~12.6 GB/vecka
- 284 GB ledigt utrymme på `/` → flera veckors marginal

### Automatisk nödrensning

Om Frigate beräknar att mindre än en timmes lagring återstår raderas den äldsta
timmen inspelningar, oavsett normal retention, och åtgärden loggas. Undvik
manuell filradering medan Frigate kör. Stoppa Frigate först om en operatör efter
felsökning behöver göra en manuell nödrensning.

## Deploymentordning

**Steg 1: go2rtc på ubuntu_2 (MÅSTE köras först)**
```bash
ansible-playbook -i inventory/semaphore_inventory.yml.local deploy_docker_service/deploy_go2rtc.yml
```

**Steg 2: Förbered Frigate .env på ubuntu_main**
```bash
# Kör manuellt på ubuntu_main enligt organisationens secret-rutin.
install -m 0600 docker/frigate/.env.example /home/hugo/frigate/.env
# Fyll i bind-adress, MQTT-host, RTSP-URL och MQTT-uppgifter.
```

Playbooken skapar eller ändrar inga MQTT-användare och loggar inte `.env`-innehållet.

**Steg 3: Frigate på ubuntu_main**
```bash
ansible-playbook -i inventory/semaphore_inventory.yml.local deploy_docker_service/deploy_frigate.yml
```

## Servicekommandon

### go2rtc (ubuntu_2)
```bash
# Status
docker ps --filter name=go2rtc

# Loggar
docker logs go2rtc --tail 50 -f

# Omstart
docker restart go2rtc

# Stoppa
docker compose -f /home/ansible/repos/Ansible_playbooks_ubuntu_server/docker/go2rtc/docker-compose.yml down
```

### Frigate (ubuntu_main)
```bash
# Status
docker ps --filter name=frigate

# Loggar
docker logs frigate --tail 100 -f

# Omstart
docker restart frigate

# Stoppa
docker compose -f /home/ansible/repos/Ansible_playbooks_ubuntu_server/docker/frigate/docker-compose.yml down
```

## Lokal/runtime-validering

### go2rtc
```bash
# Verifiera RTSP-ström (från valfri maskin med ffprobe)
ffprobe rtsp://<ubuntu-2-IP>:8554/usb_camera

# Verifiera TCP-port
nc -zv <ubuntu-2-IP> 8554

# Kontrollera container-hälsa
docker inspect --format='{{.State.Health.Status}}' go2rtc
```

### Frigate
```bash
# Web UI
curl -sI http://<ubuntu-1-IP>:8971
# Förväntat: HTTP 200 eller 401 (auth)

# MQTT-verifiering (från MQTT-broker eller klient)
mosquitto_sub -h <HA-MQTT-IP> -t 'frigate/#' -v

# Kontrollera att kameraströmmen fungerar i Frigate
docker logs frigate 2>&1 | grep -i "usb_ubuntu2"
```

## CPU-prestanda och tuning

### Tröskelvärden (i7-3770S, 4C/8T)

| Mätpunkt | Gräns | Åtgärd |
|-----------|-------|--------|
| Frigate CPU | < 50% | OK |
| Frigate CPU | 50–75% | Övervaka, överväg sänkt fps |
| Frigate CPU | > 75% | Mät decode/inference och sänk detect-upplösningen först |
| go2rtc CPU | < 60% | OK för software transcode + rotation |
| go2rtc CPU | > 80% | Sänk framerate/upplösning |

### Tuning-ordning (vid hög CPU)

1. Mät separat: go2rtc-omkodning, Frigate decode och detector/inference.
2. Sänk `detect.width`/`height` till 640×360 (behåll cirka 5 fps).
3. Om omkodningen på ubuntu_2 är flaskhalsen, sänk USB-strömmen till 640×360.
4. Överväg VAAPI för video separat efter verifierat drivrutinsstöd.
5. HD Graphics 4000 är för gammal för Frigates officiella OpenVINO GPU-stöd.
   Objektdetekteringen kör därför OpenVINO på CPU med SSDLite MobileNet v2.

## Brandvägg

> **UFW är inaktivt** på båda värdarna.

Portar binds till respektive värds specifika LAN-IP, vilket
**minskar exponering på nätverksgränssnittet** men **skyddar INTE mot
åtkomst från andra enheter på samma LAN-segment**.

⚠️ **Viktigt:** IP-bindning ersätter inte en brandvägg. För att faktiskt
begränsa åtkomst till specifika källadresser krävs:
- Router-/switch-ACL:er på nätverksnivå, **eller**
- Godkända `DOCKER-USER` iptables-regler på värden

> Inga brandväggsregler skapas automatiskt av dessa playbooks.
> Konfigurera nätverkssäkerhet manuellt innan tjänsterna exponeras.

## GPU/VAAPI-anteckning

Båda värdarna har Intel HD Graphics 4000 (Ivy Bridge) på `/dev/dri/renderD128`.
Frigate 0.17 kräver dock **Intel 6:e generationen (Skylake) eller nyare** för
officiellt OpenVINO-stöd. VAAPI kan potentiellt användas för
videoavkodning/kodning i framtiden, men **används inte initialt**.

## Omstartstest

Efter systemomstart:
1. Verifiera att go2rtc startar automatiskt (`restart: unless-stopped`)
2. Verifiera att Frigate startar automatiskt
3. Testa RTSP-ström: `ffprobe rtsp://<ubuntu-2-IP>:8554/usb_camera`
4. Öppna Frigate UI: `http://<ubuntu-1-IP>:8971`
5. Kontrollera MQTT: `mosquitto_sub -h <HA-MQTT-IP> -t 'frigate/available' -C 1`

### Senaste verifierade driftstatus

Containeromstart testades kontrollerat i beroendeordning: Frigate stoppades,
go2rtc stoppades/startades och verifierades, därefter startades Frigate.

| Kontroll | Resultat |
|----------|----------|
| go2rtc efter omstart | Healthy; H.264 1280×720, 10 fps |
| Frigate efter omstart | Healthy; kamera/process 5 fps |
| MQTT efter omstart | `frigate/available=online` |
| Frigate CPU/RAM | cirka 29–34% av en CPU-kärna / 735 MiB med OpenVINO CPU |
| go2rtc CPU/RAM | cirka 54% av en CPU-kärna / 50 MiB med YUYV + rotation |
| OpenVINO inference | cirka 10 ms; tidigare TFLite CPU cirka 43 ms |
| Frigate-disk | 279 GB ledigt vid deployment |
| Frigate SHM | 192 MB; höjt efter runtime-rekommendation om minst 146 MB |
| Temperatur | Ej mätbar ännu; `lm-sensors` är inte installerat |

go2rtc-omkodningen är den tydliga CPU-flaskhalsen. Hostens load var låg och inga
backup-processer var aktiva vid mättillfället, men påverkan under ett faktiskt
backupfönster måste fortfarande observeras.

## Rollback

### go2rtc
```bash
ansible-playbook -i inventory/semaphore_inventory.yml.local tear_down_service/tear_down_go2rtc.yml
# Config bevaras i /home/hugo/go2rtc/
```

### Frigate
```bash
ansible-playbook -i inventory/semaphore_inventory.yml.local tear_down_service/tear_down_frigate.yml
# Config och media bevaras i /home/hugo/frigate/
```

Teardown-playbookarna saknar medvetet data-wipe. Manuell dataradering ingår inte
i normal rollback. Återgå därefter till föregående Git-commit/tag och kör den
tidigare deploymentversionen om en repo-rollback behövs. Inga backupjobb på
ubuntu_2 ändras av deploy eller rollback.

## Lägga till fler kameror

### RTSP/ONVIF-kameror (direkt till Frigate)

Lägg till i `docker/frigate/config.yml` under `go2rtc.streams`:
```yaml
go2rtc:
  streams:
    usb_ubuntu2:
      - "{FRIGATE_USB_CAMERA_RTSP_URL}"
    ny_kamera:
      - "{FRIGATE_NEW_CAMERA_RTSP_URL}"
```

Lägg till kamera under `cameras:`:
```yaml
cameras:
  ny_kamera:
    enabled: true
    ffmpeg:
      inputs:
        - path: "rtsp://127.0.0.1:8554/ny_kamera"
          roles: [detect, record]
      input_args: preset-rtsp-restream
    detect:
      width: 1920
      height: 1080
      fps: 5
    objects:
      track: [person]
```

Starta om Frigate efter konfigurationsändring.

Lägg kamerans RTSP-URL/credentials i den hostlokala `.env`- eller secret-rutinen,
inte i Git. ONVIF används bara för funktioner som PTZ; Frigate behöver fortfarande
kamerans medieström via RTSP/go2rtc.

### Ytterligare USB-kameror på ubuntu_2

Lägg till device i `docker/go2rtc/docker-compose.yml` och stream i
`docker/go2rtc/go2rtc.yaml`. Starta om go2rtc.

## Home Assistant-integrering

### MQTT-baserad (automatisk)

Frigate publicerar till MQTT `frigate/#`. Med Frigate-integrationen i HA:

| HA-fält | Värde |
|---------|-------|
| MQTT topic prefix | `frigate` |
| Frigate URL | `http://<ubuntu-1-IP>:8971` |
| Frigate RTSP | `rtsp://<ubuntu-1-IP>:8554/usb_ubuntu2` |

### Vad som INTE ingår

- ❌ Inga ändringar görs i Home Assistant-konfigurationen
- ❌ Frigate installeras **inte** på HA (körs separat på ubuntu_main)
- ❌ Inga backup-playbooks för ubuntu_2
- ❌ Inga backup-modifieringar görs

## Handovermall till Home Assistant-projektet

Fyll i efter godkänd deployment och runtime-test; secrets ska maskeras.

```text
=== FRIGATE HANDOVER ===
ubuntu-1 IP/hostname: <inventoryvärde> / ubuntu-1 (ubuntu_main)
ubuntu-2 IP/hostname: <inventoryvärde> / ubuntu-2 (ubuntu_2)
Frigate-version/digest: 0.17.2 / sha256:d4351369984d4a9e2a49ac59736f6490856a7ea11f7790040746d21496967010
go2rtc-version/digest: 1.9.14 / sha256:675c318b23c06fd862a61d262240c9a63436b4050d177ffc68a32710d9e05bae
Frigate URL för HA: http://<ubuntu-1-IP>:8971
Frigate RTSP-host och port: <ubuntu-1-IP>:8554
Kameranamn i Frigate: usb_ubuntu2
Kamerans RTSP-restream: rtsp://<ubuntu-1-IP>:8554/usb_ubuntu2
MQTT broker: <HA-MQTT-IP>:1883
MQTT topic_prefix: frigate
MQTT client_id: frigate_ubuntu1
MQTT-användare: MASKERAD
CPU-detektor: OpenVINO på CPU, SSDLite MobileNet v2, inference cirka 10 ms
Detect-upplösning/fps: 1280x720 / 5 fps
Inspelningsplats: /home/hugo/frigate/media
Retention: person-alerts 7 dagar, snapshots 7 dagar, continuous/motion 0
Frigate CPU/RAM: cirka 29–34% av en CPU-kärna / 735 MiB
go2rtc CPU/RAM: cirka 54% av en CPU-kärna / 50 MiB
Testad persondetektering: ja
Testad snapshot: ja
Testad inspelning: ja
Testad omstart: ja (kontrollerad containeromstart)
Brandväggsregler: UFW inaktiv; inga regler ändrade
Kända varningar: YUYV→H.264 + rotation använder cirka halva en CPU-kärna; OpenVINO använder CPU eftersom HD4000 GPU inte stöds; temperatur ej mätt
Relevanta loggutdrag: camera/capture process started; OpenVINO inference cirka 10 ms; inga kvarvarande SHM-fel
Frigate config med secrets maskerade: docker/frigate/config.yml + maskerade FRIGATE_* värden
Ändrade repo-filer: se git diff för implementationen
Rollback-instruktion: kör teardown-playbookarna; data bevaras; checkout föregående commit/tag
```
