FROM alpine:3.10.3

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
  && rm -rf /var/cache/apk/*

ADD assets/entrypoint.sh /bin/entrypoint.sh

RUN chmod +x /bin/entrypoint.sh

USER 1001

ENTRYPOINT ["/bin/entrypoint.sh"]
