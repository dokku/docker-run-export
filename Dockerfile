FROM golang:1.26.1-trixie

# hadolint ignore=DL3027
RUN apt-get update \
    && apt install apt-transport-https build-essential curl gnupg2 jq lintian rsync rubygems-integration ruby-dev ruby -qy \
    && git clone https://github.com/bats-core/bats-core.git /tmp/bats-core \
    && /tmp/bats-core/install.sh /usr/local \
    && curl -o /usr/local/bin/yq -sL https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 \
    && chmod +x /usr/local/bin/yq \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# hadolint ignore=DL3028
RUN gem install --quiet rake fpm package_cloud

WORKDIR /src
