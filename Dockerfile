FROM registry.access.redhat.com/ubi8/ubi:8.5-226 AS builder

RUN dnf install -y gcc make

RUN cd /tmp \
  && curl https://download.redis.io/redis-stable.tar.gz -o redis-stable.tar.gz \
  && tar -xvf redis-stable.tar.gz \
  && cd redis-stable/ \
  && make distclean \
  && make

FROM registry.access.redhat.com/ubi8/ubi:8.5-226

COPY --from=builder /tmp/redis-stable/src/redis-cli /usr/local/bin

ADD repo/*.repo /etc/yum.repos.d/

# BASE
RUN rpm -ivh https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm \
  && rpm -ivh https://download.postgresql.org/pub/repos/yum/reporpms/EL-8-x86_64/pgdg-redhat-repo-latest.noarch.rpm \
  && dnf install -y \
    podman \
    podman-docker \
    podman-compose \
    podman-plugins \
    htop \
    bind-utils \
    wget \
    curl \
    nmap \
    mariadb-connector-c \
    vim \
    openssl \
    bash \
    jq \
    sudo \
    iputils \
    libnfs-utils \
    zip \
    p7zip \
    unzip \
    rsync \
    # strace \
    mongocli \
    postgresql14 \
    httpd-tools \
    git \
    tar \
    gzip \
    curl \
    ca-certificates \
    gettext \
    python2 \
    openldap-clients \
    openssh-clients \
    proxychains-ng \
    logrotate \ 
  && rpm -ivh https://vault.centos.org/8.5.2111/BaseOS/x86_64/os/Packages/tree-1.7.0-15.el8.x86_64.rpm \
  && rpm -ivh https://vault.centos.org/8.5.2111/AppStream/x86_64/os/Packages/redis-6.0.9-5.module_el8.4.0+956+a52e9aa4.x86_64.rpm \
  && dnf clean all

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
