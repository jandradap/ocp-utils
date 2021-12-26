FROM alpine:3.15

ARG BUILD_DATE
ARG VCS_REF
ARG VERSION
LABEL org.label-schema.build-date=$BUILD_DATE \
			org.label-schema.name="ocp-utils" \
			org.label-schema.description="Generates table of contents for markdown files inside local git repository." \
			org.label-schema.url="http://andradaprieto.es" \
			org.label-schema.vcs-ref=$VCS_REF \
			org.label-schema.vcs-url="https://github.com/jandradap/ocp-utils" \
			org.label-schema.vendor="Jorge Andrada Prieto" \
			org.label-schema.version=$VERSION \
			org.label-schema.schema-version="1.0" \
			maintainer="Jorge Andrada Prieto <jandradap@gmail.com>"

# BASE
RUN apk --update --clean-protected --no-cache add \
  drill \
  htop \
  bind-tools \
  wget \
  curl \
  nmap \
  mariadb-client \
  vim \
  openssl \
  bash \
  jq \
  sudo \
  iputils \
  busybox-extras \
  nfs-utils \
  zip \
  p7zip \
  unzip \
  rsync \
  strace \
  mongodb-tools \
  tree \
  redis \
  postgresql \
  apache2-utils \
  git \
  tar \
  gzip \
  curl \
  ca-certificates \
  gettext \
  python2 \
  openldap-clients \
  openssh-client \
  && python -m ensurepip \
  && rm -r /usr/lib/python*/ensurepip \
  && pip install --upgrade \
  pip \
  setuptools \
  pyzmail \
  yq \
  && rm -rf /var/cache/apk/*

# GLIBC FOR OC BINARY
ENV LANG=C.UTF-8

ARG ALPINE_GLIBC_BASE_URL="https://github.com/sgerrand/alpine-pkg-glibc/releases/download"
ARG ALPINE_GLIBC_PACKAGE_VERSION="2.30-r0"
ARG ALPINE_GLIBC_BASE_PACKAGE_FILENAME="glibc-$ALPINE_GLIBC_PACKAGE_VERSION.apk"
ARG ALPINE_GLIBC_BIN_PACKAGE_FILENAME="glibc-bin-$ALPINE_GLIBC_PACKAGE_VERSION.apk"
ARG ALPINE_GLIBC_I18N_PACKAGE_FILENAME="glibc-i18n-$ALPINE_GLIBC_PACKAGE_VERSION.apk"

RUN apk add --no-cache --virtual=.build-dependencies wget ca-certificates && \
    echo \
        "-----BEGIN PUBLIC KEY-----\
        MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEApZ2u1KJKUu/fW4A25y9m\
        y70AGEa/J3Wi5ibNVGNn1gT1r0VfgeWd0pUybS4UmcHdiNzxJPgoWQhV2SSW1JYu\
        tOqKZF5QSN6X937PTUpNBjUvLtTQ1ve1fp39uf/lEXPpFpOPL88LKnDBgbh7wkCp\
        m2KzLVGChf83MS0ShL6G9EQIAUxLm99VpgRjwqTQ/KfzGtpke1wqws4au0Ab4qPY\
        KXvMLSPLUp7cfulWvhmZSegr5AdhNw5KNizPqCJT8ZrGvgHypXyiFvvAH5YRtSsc\
        Zvo9GI2e2MaZyo9/lvb+LbLEJZKEQckqRj4P26gmASrZEPStwc+yqy1ShHLA0j6m\
        1QIDAQAB\
        -----END PUBLIC KEY-----" | sed 's/   */\n/g' > "/etc/apk/keys/sgerrand.rsa.pub" && \
    wget \
        "$ALPINE_GLIBC_BASE_URL/$ALPINE_GLIBC_PACKAGE_VERSION/$ALPINE_GLIBC_BASE_PACKAGE_FILENAME" \
        "$ALPINE_GLIBC_BASE_URL/$ALPINE_GLIBC_PACKAGE_VERSION/$ALPINE_GLIBC_BIN_PACKAGE_FILENAME" \
        "$ALPINE_GLIBC_BASE_URL/$ALPINE_GLIBC_PACKAGE_VERSION/$ALPINE_GLIBC_I18N_PACKAGE_FILENAME" && \
    apk add --no-cache \
        "$ALPINE_GLIBC_BASE_PACKAGE_FILENAME" \
        "$ALPINE_GLIBC_BIN_PACKAGE_FILENAME" \
        "$ALPINE_GLIBC_I18N_PACKAGE_FILENAME" && \
    \
    rm "/etc/apk/keys/sgerrand.rsa.pub" && \
    /usr/glibc-compat/bin/localedef --force --inputfile POSIX --charmap UTF-8 "$LANG" || true && \
    echo "export LANG=$LANG" > /etc/profile.d/locale.sh && \
    \
    apk del glibc-i18n && \
    \
    rm "/root/.wget-hsts" && \
    apk del .build-dependencies && \
    rm \
        "$ALPINE_GLIBC_BASE_PACKAGE_FILENAME" \
        "$ALPINE_GLIBC_BIN_PACKAGE_FILENAME" \
        "$ALPINE_GLIBC_I18N_PACKAGE_FILENAME"

# OC and KUBECTL
RUN curl -sLo /tmp/oc.tar.gz https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/openshift-client-linux.tar.gz \
    && tar xzvf /tmp/oc.tar.gz -C /usr/local/bin/ \
    && rm -rf /tmp/oc.tar.gz \
    && chmod +x /usr/local/bin/oc \
    && chmod +x /usr/local/bin/kubectl

# HELM
RUN VERSIONHELM=$(curl --silent "https://api.github.com/repos/helm/helm/releases/latest" | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/') \
  && curl -L https://get.helm.sh/helm-${VERSIONHELM}-linux-amd64.tar.gz |tar xvz \
  && mv linux-amd64/helm /usr/bin/helm \
  && chmod +x /usr/bin/helm \
  && rm -rf linux-amd64

# ARGOCD
RUN VERSIONARGO=$(curl --silent "https://api.github.com/repos/argoproj/argo-cd/releases/latest" | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/') \
  && curl -sSL -o /usr/bin/argocd https://github.com/argoproj/argo-cd/releases/download/${VERSIONARGO}/argocd-linux-amd64 \
  && chmod +x /usr/bin/argocd

# KAM
RUN VERSIONKAM=$(curl --silent "https://api.github.com/repos/redhat-developer/kam/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/') \
  && curl -sSL -o /usr/bin/kam https://github.com/redhat-developer/kam/releases/download/${VERSIONKAM}/kam_linux_amd64 \
  && chmod +x /usr/bin/kam

# KUBESEAL
RUN VERSIONKUBESEAL=$(curl --silent "https://api.github.com/repos/bitnami-labs/sealed-secrets/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/') \
  && curl -sSL -o /usr/bin/kubeseal https://github.com/bitnami-labs/sealed-secrets/releases/download/${VERSIONKUBESEAL}/kubeseal-linux-amd64 \
  && chmod +x /usr/bin/kubeseal

# yq ultimo
ENV VERSION=v4.16.2
RUN wget https://github.com/mikefarah/yq/releases/download/${VERSION}/yq_linux_amd64.tar.gz -O - |\
  tar xz && mv yq_linux_amd64 /usr/bin/yq4

ADD assets/*.sh /bin/

RUN chmod +x /bin/*.sh

USER 1001

ENTRYPOINT ["/bin/entrypoint.sh"]
