FROM alpine:3.13

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

# ENV BASE_URL="https://storage.googleapis.com/kubernetes-helm"
ENV BASE_URL="https://get.helm.sh"
ENV TAR_FILE="helm-v3.4.2-linux-amd64.tar.gz"

RUN curl -L ${BASE_URL}/${TAR_FILE} |tar xvz \
    && mv linux-amd64/helm /usr/local/bin/helm \
    && chmod +x /usr/local/bin/helm \
    && rm -rf linux-amd64

ADD assets/entrypoint.sh /bin/entrypoint.sh
ADD assets/entrypoint_mysql_dump.sh /bin/entrypoint_mysql_dump.sh
ADD assets/entrypoint_mongo_dump.sh /bin/entrypoint_mongo_dump.sh
ADD assets/entrypoint_rsync_dump.sh /bin/entrypoint_rsync_dump.sh
ADD assets/entrypoint_redis_dump.sh /bin/entrypoint_redis_dump.sh
ADD assets/entrypoint_elasticsearch_dump.sh /bin/entrypoint_elasticsearch_dump.sh
ADD assets/entrypoint_postgresql_dump.sh /bin/entrypoint_postgresql_dump.sh

RUN chmod +x /bin/*.sh

USER 1001

ENTRYPOINT ["/bin/entrypoint.sh"]
