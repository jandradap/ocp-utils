FROM centos:centos8

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

RUN yum makecache && yum install -y epel-release\
  && yum makecache && yum install -y \
  util-linux \
  ethtool \
  bind-utils \
  htop \
  wget \
  curl \
  nmap \
  vim \
  openssl \
  bash \
  jq \
  sudo \
  iputils \
  nfs-utils \
  zip \
  p7zip \
  unzip \
  rsync \
  && yum clean all

COPY assets/mariadb.repo /etc/yum.repos.d/

RUN yum makecache \
  && yum --disablerepo=AppStream install -y MariaDB-client \
  && yum clean all

# # OC
ARG OC_VERSION=4.5

RUN curl -sLo /tmp/oc.tar.gz https://mirror.openshift.com/pub/openshift-v$(echo \
  $OC_VERSION | cut -d'.' -f 1)/clients/oc/$OC_VERSION/linux/oc.tar.gz && \
  tar xzvf /tmp/oc.tar.gz -C /usr/local/bin/ && \
  rm -rf /tmp/oc.tar.gz

# KUBECTL
RUN curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s \
  https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl \
  && mv kubectl /usr/local/bin/ \
  && chmod +x /usr/local/bin/kubectl

ADD assets/entrypoint.sh /bin/entrypoint.sh

RUN chmod +x /bin/entrypoint.sh

USER 1001

ENTRYPOINT ["/bin/entrypoint.sh"]
