# Immich Server Infrastructure Overview

**Server Profile:** Hetzner Ubuntu VPS (IPv4 disabled / IPv6-Only)
**Storage Profile:** Hetzner Storage Box (SMB/CIFS)

---

## 1. Network & Reverse Proxy

The server operates entirely on an IPv6 network. Traffic routing and SSL termination are handled by a Caddy web server.

* **DNS Configuration:** The domain relies strictly on an **AAAA record** pointing to the server's raw IPv6 address.
* **Web Server (Caddy):** * Deployed via Docker but configured with `network_mode: "host"`. This bypasses Docker's internal IPv4 network isolation, allowing Caddy to attach directly to the host's IPv6 interface to successfully provision Let's Encrypt SSL certificates.
    * Caddy listens for incoming HTTPS requests and proxies them to Immich on local port `127.0.0.1:2283`.

---

## 2. Application Configuration (Immich)

The Immich stack runs via Docker Compose and is highly optimized for a budget VPS environment. 

* **Resource Optimization:** The Machine Learning (ML) components are completely removed to prevent RAM and CPU exhaustion. 
    * The `immich-machine-learning` container is omitted from the `docker-compose.yml`.
    * The `.env` file explicitly sets `IMMICH_MACHINE_LEARNING_ENABLED=false`.
* **External Routing:** Inside the Immich Web UI (Administration > Settings > Server), the **External Domain** is hardcoded to ensure all shareable links generate correctly.

---

## 3. Storage Subsystem

All photo and video assets are offloaded to a massive remote Hetzner Storage Box to keep the local VPS hard drive clean.

* **Mount Point:** The remote drive is mapped to `/mnt/storagebox`.
* **Immich Upload Path:** The `.env` file points Immich to the remote drive via `UPLOAD_LOCATION=/mnt/storagebox/immich-library`.
* **Authentication:** SMB credentials are securely stored in a locked file at `/root/.smbcredentials`. (Note: The password utilizes an alphanumeric format with an underscore to satisfy CIFS compatibility).
* **Fstab Configuration (`/etc/fstab`):** The drive is configured to auto-mount on system boot using a hardcoded SMB 3.0 protocol to guarantee connection stability and bypass auto-negotiation failures. 
