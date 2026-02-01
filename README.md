# Sarcophagus
### v1.0 // EXODIA PROTOCOL

**The tomb for your digital history.**

Sarcophagus is a headless Docker container designed to automate the compression, optimization, and preservation of retro game libraries. It provides a simple **Web UI (OliveTin)** to manage terabytes of ROMs without needing to touch the command line.

---

## ⚰️ Features

* **Web Control Terminal:** All operations are triggered via a sleek, mobile-friendly dashboard (OliveTin).
* **The Exodia Protocol:** A standardized compression strategy for every generation of gaming.
    * **Optical (PS1/PS2/Saturn/DC):** Converts ISO/BIN to **CHD** (Lossless, ~40-60% smaller).
    * **Nintendo (GC/Wii):** Converts ISO to **RVZ** (Lossless, ~30-70% smaller).
    * **Modern Flash (Switch):** Compresses NSP/XCI to **NSZ** (Block compression).
    * **Xbox (Original):** Scrubs dummy padding from ISOs (Destructive but essential).
    * **Handhelds (Vita):** Archives raw folders into installable **VPK** files.
    * **Retro Carts:** Batch archives NES, SNES, Genesis, etc., into standard **ZIP** format.
    * **Trimmers:** Removes padding from **3DS** roms and decrypts **PS3** ISOs to folders.
* **Self-Healing:** Includes verification routines to ensure no data is lost during compression.
* **Zero-Inference:** Scripts detect the file type automatically; you just point to the folder.

---

## 🏛️ Supported Systems

| System | Source Format | Target Format | Tool Used |
| :--- | :--- | :--- | :--- |
| **PlayStation 1 & 2** | `.bin` / `.cue` / `.iso` | **`.chd`** | `chdman` |
| **Sega Saturn / CD** | `.bin` / `.cue` | **`.chd`** | `chdman` |
| **Dreamcast** | `.gdi` | **`.chd`** | `chdman` |
| **GameCube / Wii** | `.iso` / `.gcm` | **`.rvz`** | `dolphin-tool` |
| **Nintendo Switch** | `.nsp` / `.xci` | **`.nsz`** | `nsz` |
| **Original Xbox** | `.iso` | **`.iso`** (Trimmed) | `extract-xiso` |
| **PS Vita** | Folder (NoNpDrm) | **`.vpk`** | `7zip` |
| **PS3** | `.iso` (Encrypted) | **Folder** (Decrypted) | `7zip` |
| **Nintendo 3DS** | `.3ds` | **`.3ds`** (Trimmed) | `python` |
| **Retro Carts** | Raw ROMs | **`.zip`** | `7zip` |

---

## 🚀 Installation (Unraid / Docker)

### 1. Install from Docker Hub
Sarcophagus is hosted on Docker Hub. You can install it on any system running Docker.

* **Image:** `corruptcache/sarcophagus:latest`
* **Port:** `1337` (Web UI)

### 2. Volume Mappings (Critical)
You must map your game library and your configuration folder correctly.

| Container Path | Host Path | Description |
| :--- | :--- | :--- |
| `/data` | `/mnt/user/Games/` | The root of your ROM library. |
| `/config` | `/mnt/user/appdata/sarcophagus/` | Where `config.yaml` lives. |

### 3. The "Brain" (Configuration)
By default, the Web UI will be empty. You must provide the control interface file.

1.  Start the container once to generate the `/config` folder on your host.
2.  Download the standard [olivetin.yaml](conf/olivetin.yaml) from this repository.
3.  Rename it to **`config.yaml`**.
4.  Place it in your appdata folder: `/mnt/user/appdata/sarcophagus/config.yaml`.
5.  Restart the container.

---

## 🎮 Usage

1.  Open your browser to `http://<YOUR-SERVER-IP>:1337`.
2.  Select the **Action** corresponding to your system (e.g., "Compress to CHD").
3.  Select the **Target Folder** from the dropdown menu.
4.  Click **Start**.

*The dashboard will show live logs of the compression process. You can close the window; the process will continue in the background.*

---

## ⚠️ Safety Protocols

* **Revertible:** CHD, RVZ, NSZ, and ZIP formats are lossless. You can convert them back to their original 1:1 dump at any time using the **"Revert"** buttons in the UI.
* **Destructive:** Xbox Scrubbing and 3DS Trimming permanently remove dummy data (zeros). While the game plays perfectly, the file hash will no longer match Redump/No-Intro databases.

---

## 🛠️ Building Locally

If you want to modify the scripts or tools:

```bash
git clone [https://github.com/corruptcache/sarcophagus.git](https://github.com/corruptcache/sarcophagus.git)
cd sarcophagus
docker build -t sarcophagus:local .
