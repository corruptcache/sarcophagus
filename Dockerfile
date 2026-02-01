# ==========================================
# SARCOPHAGUS v1.0
# ==========================================

# --- STAGE 1: THE FORGE (Builder) ---
FROM ubuntu:22.04 AS builder
ENV DEBIAN_FRONTEND=noninteractive

# 1. Install Build Dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    git \
    pkg-config \
    zlib1g-dev \
    libzstd-dev

# 2. Build extract-xiso (Xbox)
WORKDIR /tmp/xiso
RUN git clone https://github.com/XboxDev/extract-xiso.git . && \
    mkdir build && cd build && \
    cmake .. && make

# 3. Build ZArchive (Wii U .wua support)
WORKDIR /tmp/zarchive
RUN git clone https://github.com/Exzap/ZArchive.git . && \
    mkdir build && cd build && \
    cmake .. && make


# --- STAGE 2: THE TOMB (Final Image) ---
FROM ubuntu:22.04
LABEL maintainer="CorruptCache"
ENV DEBIAN_FRONTEND=noninteractive
ENV SCRIPT_DIR="/scripts"

# 1. Install Runtime Dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    software-properties-common \
    curl wget gnupg git nano \
    python3 python3-pip \
    7zip \
    mame-tools \
    ffmpeg \
    zlib1g \
    libssl-dev \
    libzstd1 && \
    add-apt-repository ppa:ubuntuhandbook1/dolphin-emu -y && \
    apt-get update && \
    apt-get install -y --no-install-recommends dolphin-emu && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# 2. Install Python Tools (Switch)
RUN pip3 install --no-cache-dir nsz

# 3. Copy Compiled Tools
COPY --from=builder /tmp/xiso/build/extract-xiso /usr/local/bin/extract-xiso
COPY --from=builder /tmp/zarchive/build/zarchive /usr/local/bin/zarchive

# 4. Install OliveTin
RUN VERSION=$(curl -s https://api.github.com/repos/OliveTin/OliveTin/releases/latest | grep "tag_name" | awk '{print substr($2, 2, length($2)-3)}') && \
    curl -L "https://github.com/OliveTin/OliveTin/releases/download/${VERSION}/OliveTin_linux_amd64.deb" -o OliveTin.deb && \
    dpkg -i OliveTin.deb && \
    rm OliveTin.deb

# 5. Add Scripts
COPY scripts /scripts
RUN chmod -R +x /scripts

# 6. Setup Auto-Config [NEW]
# Create a defaults folder and copy your local config there
RUN mkdir -p /defaults
COPY conf/olivetin.yaml /defaults/config.yaml

WORKDIR /config
EXPOSE 1337

# 7. Set Entrypoint [NEW]
# Use the script we just created to handle the setup
ENTRYPOINT ["/scripts/entrypoint.sh"]
CMD ["OliveTin"]
