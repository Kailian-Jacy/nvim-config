FROM --platform=linux/amd64 ubuntu:22.04

ARG LISTEN_IP=0.0.0.0
ARG LISTEN_PORT=9099
ARG DEBIAN_FRONTEND=noninteractive

EXPOSE ${LISTEN_PORT}

# Install minimal bootstrap deps (setup.sh handles the rest).
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    zsh curl coreutils git ca-certificates sudo \
  && rm -rf /var/lib/apt/lists/*

COPY . /app/
WORKDIR /app

# setup.sh auto-detects Docker and uses apt + binary downloads.
RUN chmod +x /app/setup.sh \
  && /bin/zsh /app/setup.sh --docker

COPY docker-entrypoint.sh /app/docker-entrypoint.sh
RUN chmod +x /app/docker-entrypoint.sh

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
  CMD nvim --headless -c 'echo "ok"' -c 'quit' 2>/dev/null || exit 1

ENTRYPOINT ["/app/docker-entrypoint.sh"]
