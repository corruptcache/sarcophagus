# ==========================================
# SARCOPHAGUS v2 (OMNIBUS)
# Universal Compression: ISO, CHD, RVZ, NSZ, XISO, WUA
# ==========================================

# --- STAGE 1: THE FORGE (Builder) ---
# We use this stage to compile tools that aren't in apt-get
FROM ubuntu:22.04 AS builder
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    git \
    zlib1g-dev

# 1. Build extract-xiso (Xbox)
WORKDIR /tmp/xiso
RUN git clone https://github.com/XboxDev/extract-xiso.git . && \
    mkdir build && cd build && \
    cmake .. && make

# 2. Build ZArchive (Wii U .wua support)
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
    # Required for Switch compression
    libssl-dev && \
    # Add Dolphin PPA
    add-apt-repository ppa:ubuntuhandbook1/dolphin-emu -y && \
    apt-get update && \
    apt-get install -y --no-install-recommends dolphin-emu && \
    # Clean up
    apt-get clean && rm -rf /var/lib/apt/lists/*

# 2. Install Python Tools (Switch)
# 'nsz' tool compresses Switch dumps perfectly
RUN pip3 install --no-cache-dir nsz

# 3. Copy Compiled Tools from The Forge
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



WORKDIR /config
EXPOSE 1337
CMD ["/usr/bin/OliveTin"]
