# VPS Infrastructure Monorepo

**Server Profile:** Hetzner Ubuntu VPS (IPv4 disabled / IPv6-Only)
**Storage Profile:** Hetzner Storage Box (SMB/CIFS)

This repository acts as the master Infrastructure-as-Code (IaC) configuration for the entire server. It dictates the network routing, application configurations, and external storage connections.

---

## 1. Network Architecture & DNS

The server operates entirely on an IPv6 network. Because it lacks a native IPv4 address, it relies on public NAT64/DNS64 translators to pull data from IPv4-only services (like GitHub).

* **NAT64 Translators:** Configured directly in `/etc/resolv.conf` to intercept and translate outbound IPv4 requests.
* **DNS Configuration:** All hosted subdomains rely strictly on **AAAA records** pointing to the server's raw IPv6 address.
* **Web Server (Caddy):** Handles all reverse proxying and SSL termination. It is configured with `network_mode: "host"` to attach directly to the host's IPv6 interface, bypassing Docker's internal IPv4 restrictions to successfully provision Let's Encrypt certificates.

---

## 2. Storage Subsystem

All heavy assets (photos, files, documents) are offloaded to a remote Hetzner Storage Box to keep the local VPS hard drive clean and operations lightweight.

* **Mount Point:** The remote drive is mapped to `/mnt/storagebox`.
* **Authentication:** SMB credentials are securely stored in a locked file at `/root/.smbcredentials`.
* **Fstab Configuration (`/etc/fstab`):** The drive auto-mounts on system boot using a hardcoded SMB 3.0 protocol (`vers=3.0`) to guarantee connection stability and bypass auto-negotiation failures.

**Current Mount Entry:**
`//u571770.your-storagebox.de/backup /mnt/storagebox cifs vers=3.0,credentials=/root/.smbcredentials,uid=1000,gid=1000,file_mode=0660,dir_mode=0770 0 0`

---

## 3. Application Stack

### Caddy (Global Gateway)
* **Location:** Deployed alongside the Immich stack but acts as the global web server.
* **Function:** Listens for incoming HTTPS requests and routes them to local application ports (e.g., Immich on `2283`, Nextcloud on `8080`).

### Immich (`/immich-app`)
* **Domain:** `https://photos.axkirillov.com`
* **Storage:** Maps to `/mnt/storagebox/immich-library`
* **Optimization:** Machine Learning (ML) components are completely removed (`IMMICH_MACHINE_LEARNING_ENABLED=false`) to prevent RAM/CPU exhaustion on the budget VPS.
* **Secrets:** Database credentials are kept in an untracked `.env` file. The PostgreSQL database is untracked to keep the Git repository lightweight.

### Nextcloud (`/nextcloud-app`)
* **Domain:** `https://cloud.axkirillov.com`
* **Storage:** Maps to `/mnt/storagebox/nextcloud-data`
* **Optimization:** Uses the `linuxserver/nextcloud` image, specifically configured with `PUID=1000` and `PGID=1000`. This solves the "two-tenant" storage problem, allowing Nextcloud to securely write to the same mounted Storage Box as Immich without throwing permissions errors.
