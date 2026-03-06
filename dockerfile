FROM --platform=linux/amd64 ubuntu:22.04

ARG LISTEN_IP=0.0.0.0
ARG LISTEN_PORT=9099
ARG DEBIAN_FRONTEND=noninteractive

ENV LISTEN_IP=${LISTEN_IP}
ENV LISTEN_PORT=${LISTEN_PORT}

EXPOSE ${LISTEN_PORT}

# Install system dependencies via apt (no homebrew in Docker).
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    curl \
    wget \
    git \
    gcc \
    g++ \
    make \
    cmake \
    unzip \
    zip \
    xsel \
    tmux \
    ripgrep \
    fd-find \
    lua5.4 \
    sqlite3 \
    libsqlite3-dev \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js (LTS) via NodeSource.
RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# Install Neovim (stable release).
RUN curl -fsSL -o /tmp/nvim-linux64.tar.gz \
      "https://github.com/neovim/neovim/releases/latest/download/nvim-linux64.tar.gz" \
    && tar -C /opt -xzf /tmp/nvim-linux64.tar.gz \
    && ln -s /opt/nvim-linux64/bin/nvim /usr/local/bin/nvim \
    && rm /tmp/nvim-linux64.tar.gz

# Install lazygit.
RUN LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" \
      | grep -Po '"tag_name": *"v\K[^"]*') \
    && curl -fsSL -o /tmp/lazygit.tar.gz \
      "https://github.com/jesseduffield/lazygit/releases/download/v${LAZYGIT_VERSION}/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz" \
    && tar -C /tmp -xzf /tmp/lazygit.tar.gz lazygit \
    && install /tmp/lazygit /usr/local/bin/ \
    && rm /tmp/lazygit.tar.gz /tmp/lazygit

# Install zoxide.
RUN curl -fsSL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash

# Install fzf.
RUN git clone --depth 1 https://github.com/junegunn/fzf.git /opt/fzf \
    && /opt/fzf/install --bin \
    && ln -s /opt/fzf/bin/fzf /usr/local/bin/fzf

# Install gh CLI.
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
      | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
      > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update && apt-get install -y gh \
    && rm -rf /var/lib/apt/lists/*

# Install vscode-langservers-extracted.
RUN npm i -g vscode-langservers-extracted

# Copy config.
COPY . /app/
WORKDIR /app

# Link nvim config.
RUN mkdir -p ~/.config \
    && ln -sf /app/config.nvim ~/.config/nvim

# Install plugins (allow failure — user can re-run later).
RUN timeout 300 nvim --headless +":Lazy restore" +q 2>&1 || true
RUN timeout 300 nvim --headless +"lua print('Plugins loaded.')" +q 2>&1 || true

# Copy entrypoint script.
COPY docker-entrypoint.sh /app/docker-entrypoint.sh
RUN chmod +x /app/docker-entrypoint.sh

ENTRYPOINT ["/app/docker-entrypoint.sh"]
