# syntax=docker/dockerfile:1

# Build stage: compile fbd binaries from source.
FROM fbd-builder-base:swift6.2.3-jammy AS builder

# Clone the upstream project into the build workspace.
RUN git clone https://github.com/fistbump-org/fbd.git .

# Generate the build hash file expected by the project build
RUN HASH=$(git rev-parse --short=7 HEAD 2>/dev/null || echo "unknown") && \
    printf '%s\n' \
    '/// Auto-generated at build time - do not edit.' \
    "let _buildHash: String = \"${HASH}\"" \
    > Sources/Base/BuildInfo.swift

# Resolve dependencies and compile optimized release binaries.
RUN swift package resolve
RUN swift build -c release

# Runtime stage: keep Swift runtime available
FROM swift:6.2.3-jammy

# Install only runtime packages to keep the final image smaller.
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    tzdata \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /root

# Copy compiled executables from the build stage into PATH.
COPY --from=builder /src/.build/release/fbd /usr/local/bin/fbd
COPY --from=builder /src/.build/release/fbdctl /usr/local/bin/fbdctl

# Copy startup script into the runtime image and normalize line endings
# to avoid shell parsing issues on Windows checkouts.
COPY src/fdb/script/start-fbd.sh /opt/start-fbd.sh
RUN sed -i 's/\r$//' /opt/start-fbd.sh && chmod 755 /opt/start-fbd.sh

# Expose peer, API and RPC ports used by fbd.
EXPOSE 32867 32869 32870
# Persist node data across container restarts.
VOLUME ["/root/.fbd"]

# Default startup command for standalone container usage.
CMD ["fbd", "--network", "main", "--host", "0.0.0.0", "--rpc-host", "0.0.0.0"]
