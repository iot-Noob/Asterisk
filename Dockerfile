FROM debian:bookworm-slim AS builder

# Install build dependencies
RUN apt-get update && \
    apt-get install -y \
    wget \
    tar \
    gcc \
    g++ \
    make \
    libxml2-dev \
    libssl-dev \
    libsqlite3-dev \
    libjansson-dev \
    libedit-dev \
    pkg-config \
    curl \
    libncurses5-dev \
    liburiparser-dev \
    libcurl4-openssl-dev \
    libxslt1-dev \
    uuid-dev \
    libsrtp2-dev \
    libgsm1-dev \
    libspeex-dev \
    libspeexdsp-dev \
    libopus-dev \
    libcodec2-dev \
    unixodbc-dev \
    freetds-dev \
    libpq-dev \
    libldap2-dev \
    libical-dev \
    libneon27-dev \
    libgmime-3.0-dev \
    liblua5.2-dev \
    bzip2 \
    patch \
    git \
    bison \
    flex \
    subversion \
    && rm -rf /var/lib/apt/lists/*

# Download Asterisk 22.5.0
ARG ASTERISK_VERSION=22.5.0
WORKDIR /usr/src
RUN wget -4 https://downloads.asterisk.org/pub/telephony/asterisk/releases/asterisk-${ASTERISK_VERSION}.tar.gz && \
    tar xzf asterisk-${ASTERISK_VERSION}.tar.gz && \
    rm asterisk-${ASTERISK_VERSION}.tar.gz
WORKDIR /usr/src/asterisk-${ASTERISK_VERSION}

# Configure with bundled pjproject
RUN ./configure --with-jansson-bundled --with-pjproject-bundled && \
    ./contrib/scripts/get_mp3_source.sh

# Create menuselect options
RUN make menuselect.makeopts

# Enable commonly used modules (adjust as needed)
RUN menuselect/menuselect \
    --enable app_voicemail \
    --enable app_voicemail_odbc \
    --enable app_queue \
    --enable app_record \
    --enable app_stasis \
    --enable res_ari \
    --enable res_ari_applications \
    --enable res_ari_asterisk \
    --enable res_ari_bridges \
    --enable res_ari_channels \
    --enable res_ari_device_states \
    --enable res_ari_endpoints \
    --enable res_ari_events \
    --enable res_ari_mailboxes \
    --enable res_ari_playbacks \
    --enable res_ari_recordings \
    --enable res_ari_sounds \
    --enable res_stasis \
    --enable res_stasis_answer \
    --enable res_stasis_device_state \
    --enable res_stasis_playback \
    --enable res_stasis_recording \
    --enable res_stasis_snoop \
    --enable res_pjsip \
    --enable res_pjsip_acl \
    --enable res_pjsip_authenticator_digest \
    --enable res_pjsip_endpoint_identifier_ip \
    --enable res_pjsip_endpoint_identifier_user \
    --enable res_pjsip_logger \
    --enable res_pjsip_mwi \
    --enable res_pjsip_nat \
    --enable res_pjsip_notify \
    --enable res_pjsip_outbound_registration \
    --enable res_pjsip_pubsub \
    --enable res_pjsip_refer \
    --enable res_pjsip_registrar \
    --enable res_pjsip_rfc3326 \
    --enable res_pjsip_sdp_rtp \
    --enable res_pjsip_session \
    --enable res_pjsip_t38 \
    --enable res_rtp_asterisk \
    --enable res_snmp \
    --enable res_http_websocket \
    --enable res_calendar \
    --enable res_calendar_icalendar \
    --enable res_calendar_exchange \
    --enable res_odbc \
    --enable res_odbc_transaction \
    --enable res_config_odbc \
    --enable res_mwi_external \
    --enable res_mwi_external_ami \
    --enable res_stir_shaken \
    --enable codec_opus \
    --enable codec_g722 \
    --enable codec_gsm \
    --enable codec_ulaw \
    --enable codec_alaw \
    --enable format_mp3 \
    --enable format_wav \
    --enable format_wav_gsm \
    --enable format_sln \
    --enable format_ogg_vorbis \
    --enable CORE-SOUNDS-EN-WAV \
    --enable CORE-SOUNDS-EN-ULAW \
    --enable CORE-SOUNDS-EN-ALAW \
    --enable CORE-SOUNDS-EN-GSM \
    --enable CORE-SOUNDS-EN-G722 \
    --enable EXTRA-SOUNDS-EN-WAV \
    --enable EXTRA-SOUNDS-EN-ULAW \
    --enable EXTRA-SOUNDS-EN-ALAW \
    --enable EXTRA-SOUNDS-EN-GSM \
    --enable EXTRA-SOUNDS-EN-G722 \
    --enable MOH-OPSOUND-WAV \
    --enable MOH-OPSOUND-ULAW \
    --enable MOH-OPSOUND-ALAW \
    --enable MOH-OPSOUND-GSM \
    --enable MOH-OPSOUND-G722 \
    menuselect.makeopts

# Optional: Disable modules you don't need
RUN menuselect/menuselect \
    --disable chan_console \
    menuselect.makeopts

# Compile
RUN make -j$(nproc)

# Install
RUN make install && \
    make config && \
    make samples && \
    echo "Checking sound files..." && \
    ls -la /var/lib/asterisk/sounds/en/ | head -20 && \
    echo "Checking MOH files..." && \
    ls -la /var/lib/asterisk/moh/ || echo "WARNING: MOH directory is empty!"

# If MOH files are missing, create a default one
RUN if [ ! -f /var/lib/asterisk/moh/default ]; then \
        echo "Creating default MOH file..." && \
        cp /var/lib/asterisk/sounds/en/hello-world.gsm /var/lib/asterisk/moh/default 2>/dev/null || \
        echo "Warning: Could not create default MOH file"; \
    fi

# --- Final Stage ---
FROM debian:bookworm-slim

# Install runtime dependencies
RUN apt-get update && \
    apt-get install -y \
    iputils-ping \
    nano \
    vim \
    htop \
    net-tools\
    libssl3 \
    libsqlite3-0 \
    libjansson4 \
    libedit2 \
    libcurl4 \
    libxml2 \
    libxslt1.1 \
    libuuid1 \
    libncursesw6 \
    libncurses5 \
    libct4 \
    liburiparser1 \
    libsrtp2-1 \
    libgsm1 \
    libspeex1 \
    libspeexdsp1 \
    libopus0 \
    libcodec2-1.0 \
    unixodbc \
    libpq5 \
    libldap-2.5-0 \
    libical3 \
    libneon27 \
    libgmime-3.0-0 \
    liblua5.2-0 \
    odbcinst \
    procps \
    && rm -rf /var/lib/apt/lists/*

# Copy Asterisk from builder
COPY --from=builder /usr/lib/asterisk /usr/lib/asterisk
COPY --from=builder /usr/lib/libasterisk* /usr/lib/
COPY --from=builder /usr/local/lib /usr/local/lib
COPY --from=builder /usr/sbin/asterisk /usr/sbin/asterisk
COPY --from=builder /var/lib/asterisk /var/lib/asterisk
COPY --from=builder /etc/asterisk /etc/asterisk

# Update shared library cache
RUN ldconfig

# Store a copy of samples for the entrypoint to use if /etc/asterisk is empty
RUN mkdir -p /var/lib/asterisk/sample-config /var/lib/asterisk/sample-sounds && \
    cp -a /etc/asterisk/. /var/lib/asterisk/sample-config/ || true && \
    cp -a /var/lib/asterisk/sounds/. /var/lib/asterisk/sample-sounds/ || true

# Create asterisk user with specific UID/GID for consistent volume permissions
RUN groupadd -g 1000 asterisk && \
    useradd -r -u 1000 -g asterisk -G audio,dialout asterisk && \
    mkdir -p /var/run/asterisk /var/log/asterisk /var/spool/asterisk /var/lib/asterisk/moh && \
    chown -R asterisk:asterisk /var/run/asterisk /var/log/asterisk /var/spool/asterisk /etc/asterisk /var/lib/asterisk

# Add entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Expose all necessary ports (Documentation only as network_mode: host is used)
# SIP: 5060, 5061 | RTP: 10000-20000 | ARI: 8088, 8089 | IAX2: 4569 | AMI: 5038, 5039
EXPOSE 5060/udp 5060/tcp 5061/udp 5061/tcp 10000-20000/udp 8088/tcp 8089/tcp 4569/udp 5038/tcp 5039/tcp

# Set health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD asterisk -rx "core show status" || exit 1

ENTRYPOINT ["/entrypoint.sh"]