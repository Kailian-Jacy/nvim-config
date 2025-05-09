FROM --platform=x86-64 ubuntu:22.04

EXPOSE 9099

RUN apt-get update \
  && apt-get install -y zsh curl coreutils git gcc

COPY . /app/

RUN chmod +x /app/setup.sh \
  && /bin/zsh -e /app/setup.sh

COPY --chown=nvim-user:nvim-user <<-"EOF" /app/docker-entrypoint.sh
#!/bin/zsh
set -e

while true; do
    echo "[$(date)] Starting neovim server..."
    nvim --headless --listen 0.0.0.0:9099
    echo "[$(date)] Neovim server stopped, restarting in 5 seconds..."
    sleep 5
done
EOF

RUN chmod +x /app/docker-entrypoint.sh

ENTRYPOINT ["/app/docker-entrypoint.sh"]
