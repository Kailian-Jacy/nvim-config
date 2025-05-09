FROM --platform=x86-64 ubuntu:22.04

ARG LISTEN_IP=0.0.0.0
ARG LISTEN_PORT=9099
EXPOSE 9099

RUN apt-get update \
  && apt-get install -y zsh curl coreutils git gcc

COPY . /app/

RUN chmod +x /app/setup.sh \
  && /bin/zsh -e /app/setup.sh

RUN cat <<EOF > /app/docker-entrypoint.sh 
#!/bin/zsh
set -e

while true; do
    echo "[$(date)] Starting neovim server..."
    nvim --headless --listen ${LISTEN_IP}:${LISTEN_PORT}
    echo "[$(date)] Neovim server stopped."
done
EOF

RUN chmod +x /app/docker-entrypoint.sh

ENTRYPOINT ["/app/docker-entrypoint.sh"]
