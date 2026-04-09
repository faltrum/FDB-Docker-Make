# #syntax=docker/dockerfile:1

# Reusable builder base image for fbd compilation dependencies.
FROM swift:6.2.3-jammy

# Install toolchain and native dependencies required to build the Swift project.
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    curl \
    pkg-config \
    libsqlite3-dev \
    libssl-dev \
    zlib1g-dev \
    libncurses-dev \
    libxml2-dev \
    libcurl4-openssl-dev \
    libedit-dev \
    ca-certificates \
    tzdata \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src
