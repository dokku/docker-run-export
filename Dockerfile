FROM golang:1.26.1-trixie

ARG NOMAD_VERSION=1.11.3

# hadolint ignore=DL3027,DL3008,DL3015
RUN apt-get update \
    && apt-get install -qy apt-transport-https build-essential curl gnupg2 jq lintian rsync rubygems-integration ruby-dev ruby unzip \
    && DEB_ARCH=$(dpkg --print-architecture) \
    && git clone https://github.com/bats-core/bats-core.git /tmp/bats-core \
    && /tmp/bats-core/install.sh /usr/local \
    && curl -fsSL -o /usr/local/bin/yq "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_${DEB_ARCH}" \
    && chmod +x /usr/local/bin/yq \
    && curl -fsSL -o /usr/local/bin/dasel "https://github.com/tomwright/dasel/releases/latest/download/dasel_linux_${DEB_ARCH}" \
    && chmod +x /usr/local/bin/dasel \
    && curl -fsSL -o /tmp/nomad.zip "https://releases.hashicorp.com/nomad/${NOMAD_VERSION}/nomad_${NOMAD_VERSION}_linux_${DEB_ARCH}.zip" \
    && unzip -o /tmp/nomad.zip -d /usr/local/bin/ \
    && chmod +x /usr/local/bin/nomad \
    && rm -f /tmp/nomad.zip \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# hadolint ignore=DL3028
RUN gem install --quiet rake fpm package_cloud

WORKDIR /src
