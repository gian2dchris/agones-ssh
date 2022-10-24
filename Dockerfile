FROM golang:1.19 as golang
LABEL NAME="Agones SSH" MAINTAINER="Gian Chris"

WORKDIR /src

COPY ./src .
RUN go mod tidy \
    && CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o server . \
    && go install github.com/aquasecurity/kube-bench@latest \
    && go install github.com/OJ/gobuster@latest \
    && cd /tmp && git clone https://github.com/cyberark/kubeletctl \
    && cd kubeletctl && go install github.com/mitchellh/gox@latest \
    && go mod vendor && go fmt ./... && mkdir -p build \
    && GOFLAGS=-mod=vendor gox -ldflags "-s -w" --osarch="linux/amd64" -output "build/kubeletctl"

FROM alpine:3.16
LABEL NAME="Agones SSH" MAINTAINER="Giannis Christinakis"

ENV DOCKER_VERSION=20.10.20
ENV KUBECTL_VERSION=1.25.3
ENV HELM_VERSION=3.10.1
ENV HELMV2_VERSION=2.17.0
ENV KUBEAUDIT_VERSION=0.20.0
ENV AUDIT2RBAC_VERSION=0.9.0
ENV AMICONTAINED_VERSION=0.4.9
ENV KUBESEC_VERSION=2.11.5
ENV AMASS_VERSION=3.20.0
ENV KUBECTL_WHOCAN_VERSION=0.4.0
ENV GITLEAKS_VERSION=8.15.0
ENV CFSSL_VERSION=1.6.3
# ENV OPENSSH_RELEASE=8.8_p1-r1
# ENV ETCDCTL_VERSION=3.4.9

WORKDIR /tmp
COPY --from=golang /src/server /root/server
COPY --from=golang /go/bin/kube-bench /usr/local/bin/kube-bench
COPY --from=golang /go/bin/gobuster /usr/local/bin/gobuster
COPY --from=golang /tmp/kubeletctl/build/kubeletctl /usr/local/bin/kubeletctl

COPY ./entrypoint.sh /root/entrypoint.sh

RUN apk --no-cache add \
    curl wget bash htop nmap nmap-scripts python3 py3-pip ca-certificates bind-tools \
    coreutils iputils net-tools git unzip whois tcpdump openssl proxychains-ng procps scapy \
    netcat-openbsd redis postgresql-client mysql-client masscan nikto ebtables perl-net-ssleay yaml-cpp \
    # ssh server dependencies
    logrotate nano sudo openssh-server openssh-client openssh-sftp-server \
    # end ssh server dependencies
    && curl -LO https://storage.googleapis.com/kubernetes-release/release/v${KUBECTL_VERSION}/bin/linux/amd64/kubectl \
    && mv kubectl /usr/local/bin/kubectl \
    && curl -fSLO https://download.docker.com/linux/static/stable/x86_64/docker-${DOCKER_VERSION}.tgz \
    && tar -xvzf docker-${DOCKER_VERSION}.tgz && mv docker/* /usr/local/bin/ \
    && curl -LO https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz \
    && tar -zxvf helm-v${HELM_VERSION}-linux-amd64.tar.gz && mv linux-amd64/helm /usr/local/bin/helm \
    && curl -LO https://get.helm.sh/helm-v${HELMV2_VERSION}-linux-amd64.tar.gz \
    && tar -zxvf helm-v${HELMV2_VERSION}-linux-amd64.tar.gz && mv linux-amd64/helm /usr/local/bin/helm2 \
    # && curl -fSLO https://github.com/etcd-io/etcd/releases/download/v${ETCDCTL_VERSION}/etcd-v${ETCDCTL_VERSION}-linux-amd64.tar.gz \
    # && tar -xvzf etcd-v${ETCDCTL_VERSION}-linux-amd64.tar.gz && mv etcd-v${ETCDCTL_VERSION}-linux-amd64/etcdctl /usr/local/bin/  \
    && curl -fSLO https://github.com/Shopify/kubeaudit/releases/download/v${KUBEAUDIT_VERSION}/kubeaudit_${KUBEAUDIT_VERSION}_linux_amd64.tar.gz \
    && tar -zxvf kubeaudit_${KUBEAUDIT_VERSION}_linux_amd64.tar.gz && mv kubeaudit /usr/local/bin/kubeaudit \
    && curl -LO https://github.com/liggitt/audit2rbac/releases/download/v${AUDIT2RBAC_VERSION}/audit2rbac-linux-amd64.tar.gz \
    && curl -fSL https://github.com/genuinetools/amicontained/releases/download/v${AMICONTAINED_VERSION}/amicontained-linux-amd64 -o /usr/local/bin/amicontained \
    && curl -fSLO https://github.com/controlplaneio/kubesec/releases/download/v${KUBESEC_VERSION}/kubesec_linux_amd64.tar.gz \
    && tar -xvzf kubesec_linux_amd64.tar.gz && mv kubesec /usr/local/bin/kubesec \
    && curl -fSL https://github.com/cloudflare/cfssl/releases/download/v${CFSSL_VERSION}/cfssl_${CFSSL_VERSION}_linux_amd64 -o /usr/local/bin/cfssl \
    && curl -fSLO https://github.com/OWASP/Amass/releases/download/v${AMASS_VERSION}/amass_linux_amd64.zip \
    && unzip amass_linux_amd64.zip && mv amass_linux_amd64/amass /usr/local/bin/amass \
    # && mv amass_linux_amd64/examples/wordlists /usr/share/wordlists \
    && curl -fSLO https://github.com/aquasecurity/kubectl-who-can/releases/download/v${KUBECTL_WHOCAN_VERSION}/kubectl-who-can_linux_x86_64.tar.gz \
    && tar -xvzf kubectl-who-can_linux_x86_64.tar.gz \
    && mv kubectl-who-can /usr/local/bin/kubectl-who-can \
    && git clone https://github.com/docker/docker-bench-security.git /root/docker-bench-security \
    && git clone https://github.com/CISOfy/lynis /root/lynis \
    && git clone --depth 1 https://github.com/drwetter/testssl.sh.git /usr/share/testssl \
    && ln -s /usr/share/testssl/testssl.sh /usr/local/bin/testssl \
    && curl -fSLO https://github.com/zricethezav/gitleaks/releases/download/v${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION}_linux_x64.tar.gz \
	&& tar -xvzf gitleaks_${GITLEAKS_VERSION}_linux_x64.tar.gz && mv gitleaks /usr/local/bin/gitleaks \
	&& curl -fSL https://raw.githubusercontent.com/rebootuser/LinEnum/master/LinEnum.sh -o /usr/local/bin/linenum \
    && git clone --depth 1 https://github.com/pentestmonkey/unix-privesc-check.git /root/unix-privesc-check \
    && curl -fSL https://raw.githubusercontent.com/mzet-/linux-exploit-suggester/master/linux-exploit-suggester.sh -o /usr/local/bin/linux-exploit-suggester \
    && curl -fSL https://raw.githubusercontent.com/mbahadou/postenum/master/postenum.sh -o /usr/local/bin/postenum \
    # For now we are just using the k8s manifests for leveraging the kube-hunter, in future we should support the local package
    && git clone https://github.com/aquasecurity/kube-hunter /root/kube-hunter \
    && chmod a+x /usr/local/bin/linenum /usr/local/bin/linux-exploit-suggester /usr/local/bin/cfssl \ 
    /usr/local/bin/postenum /usr/local/bin/gitleaks /usr/local/bin/kubectl /usr/local/bin/amicontained /usr/local/bin/kubeaudit /usr/local/bin/kubeletctl \
    && pip3 install --no-cache-dir awscli truffleHog \
    && echo 'http://dl-cdn.alpinelinux.org/alpine/v3.14/main' >> /etc/apk/repositories \
    && echo 'http://dl-cdn.alpinelinux.org/alpine/v3.14/community' >> /etc/apk/repositories \
    && apk update \
    && rm -rf /tmp/* \
    # start ssh
    && echo "**** setup openssh environment ****" \
    && sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/g' /etc/ssh/sshd_config \
    && sed -i 's/#Port 22/Port 2222/g' /etc/ssh/sshd_config \
    && sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/g' /etc/ssh/sshd_config \
    # end ssh
    && chmod o+x /root/server

WORKDIR /root
ENTRYPOINT [ "/root/entrypoint.sh" ]