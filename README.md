_____                                 _
  / ____|                               | |
 | (___   __ _ _ __ ___ ___  _ __  _ __ | |__   __ _  __ _ _   _ ___
  \___ \ / _` | '__/ __/ _ \| '_ \| '_ \| '_ \ / _` |/ _` | | | / __|
  ____) | (_| | | | (_| (_) | |_) | | | | | | | (_| | (_| | |_| \__ \
 |_____/ \__,_|_|  \___\___/| .__/|_| |_|_| |_|\__,_|\__, |\__,_|___/
                            | |                       __/ |
                            |_|                      |___/
             v1.0 // EXODIA PROTOCOL

# Sarcophagus

**The tomb for your digital history.**
Sarcophagus is a headless Docker container designed to automate the compression and preservation of retro game libraries.

## ⚰️ Features
* **Web UI (OliveTin):** One-click operations. No SSH required.
* **CHD Protocol:** Converts PS1/PS2/Saturn ISOs to CHD (Compression ~40-60%).
* **RVZ Protocol:** Converts GameCube/Wii ISOs to RVZ (Lossless compression).
* **Self-Healing:** Includes repair scripts for corrupt headers.

## 🚀 Installation (Unraid)
1.  Add `https://github.com/corruptcache/unraid-templates` to your Docker Templates.
2.  Install **Sarcophagus**.
3.  Map your `/data` volume to your Games folder.
