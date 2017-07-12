FROM registry.access.redhat.com/rhel7

LABEL name="coscale/coscale-agent" \
      vendor="CoScale" \
      version="3.10" \
      release="1" \
      summary="CoScale Agent" \
      description="CoScale offers full-stack monitoring for containers and microservices." \
      url="https://www.coscale.com/" \
      io.k8s.description="CoScale offers full-stack monitoring for containers and microservices." \
      io.k8s.display-name="CoScale Agent" \
      io.openshift.expose-services="" \
      io.openshift.tags="coscale,monitoring,alerting,anomaly detection"

COPY help.md /tmp/

COPY licenses /licenses

ENV COSCALE_RUNNING_IN_CONTAINER="true" \
    BASE_URL="https://api.coscale.com" \
    CERTIFICATE="LS0tLS1CRUdJTiBQVUJMSUMgS0VZLS0tLS0KTUlJQklqQU5CZ2txaGtpRzl3MEJBUUVGQUFPQ0FROEFNSUlCQ2dLQ0FRRUFuYXFWN2ROM3AxZWxFaTRiMVpRWQpoOS9qaVUyWTl5WVhBS000VWhwU0g0NUNrVlJpb01vMi9XaG9yRUJKWHdxNW51Z3VwTjJ4S1hRVldFTkxpOHZqClJaTGoxWHpKc3RkR3cyN1ZONUVSOHVtWnAySk4wZHBqckxKb1J0UWRodGdXMkxFazhIM0xmWVVjNE01OXJFSGIKWGVVR3Y4aVVQa3ZtMUl0Q0hpS1pXcFBKVzAwb1ZlV3hXaWhkLzF6V0NqVXhQQW51M1MrUmZXdnBSQWY4UDIwRgpNVUVxcXhSNGZjM0hCcklEcldqS21UK3V4V21GcVFibXd1OHF5RDVQR2wrYzEwck9MVDYxMllYc0N4OTE3bVRYCnBMRDNUR2xvZ1c0NS9ETC9aUmVhTWVMSFJTSDhjWXJUaG1CZlc4QnRBR1lad1BFZUxMUUVRai9UZmxqQ0Z4QW4KYndJREFRQUIKLS0tLS1FTkQgUFVCTElDIEtFWS0tLS0tCgo="

### Add necessary Red Hat repos here
RUN REPOLIST=rhel-7-server-rpms,rhel-7-server-optional-rpms \
### Add your package needs here
    INSTALL_PKGS="golang-github-cpuguy83-go-md2man" && \
    yum -y update-minimal --disablerepo "*" --enablerepo rhel-7-server-rpms --setopt=tsflags=nodocs \
      --security --sec-severity=Important --sec-severity=Critical && \
    yum -y install --disablerepo "*" --enablerepo ${REPOLIST} --setopt=tsflags=nodocs ${INSTALL_PKGS} && \
### help file markdown to man conversion
    go-md2man -in /tmp/help.md -out /help.1 && \
    yum clean all


ADD agent.tgz /tmp/
ADD coscale-runner.sh /tmp/
ADD docker-1.10.0 /tmp/

RUN cd /tmp/ && \
    mv docker-1.10.0 /usr/bin/docker && \
    chmod +x /usr/bin/docker && \
    mkdir -p /opt/coscale/agent/etc /opt/coscale/agent/plugins && \
    tar -xzvf agent.tgz && \
    mv coscale-agent/coscale-agent /opt/coscale/agent/ && \
    mv coscale-agent/run_in_ns /opt/coscale/agent/ && \
    mv coscale-agent/coscale-cli /opt/coscale/agent/ && \
    mv coscale-runner.sh /opt/coscale/agent/ && \
    chmod +x /opt/coscale/agent/coscale-runner.sh && \
    rm -Rf /tmp/*

CMD ["/opt/coscale/agent/coscale-runner.sh"]
