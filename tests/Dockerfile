FROM debian:stable-slim

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      bash bats ca-certificates curl gnupg jq kcov perl \
 && rm -rf /var/lib/apt/lists/*

ARG YQ_VERSION=v4.47.1
RUN ARCH="$(dpkg --print-architecture)" \
 && curl -fsSL "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_${ARCH}" \
      -o /usr/local/bin/yq \
 && chmod +x /usr/local/bin/yq
