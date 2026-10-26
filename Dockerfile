# syntax=docker/dockerfile:1
FROM rockylinux/rockylinux:9-minimal AS builder

# Optional corporate CA (local builds only): pass with
#   --secret id=cacert,src=cacert.pem
# Builds without the secret (e.g. GitHub Actions) skip this step.
RUN --mount=type=secret,id=cacert,required=false \
    if [ -s /run/secrets/cacert ]; then \
    cp /run/secrets/cacert /etc/pki/ca-trust/source/anchors/local-ca.pem \
    && update-ca-trust; \
    fi \
    && microdnf install -y unzip

RUN microdnf install -y git curl rpm-build rpmdevtools dnf dnf-plugins-core

RUN rpmdev-setuptree

RUN git clone --depth 1 --branch c9s \
    https://gitlab.com/redhat/centos-stream/rpms/brotli.git \
    brotli-el9-rpm \
    && cp brotli-el9-rpm/*.patch ~/rpmbuild/SOURCES/ \
    && cp brotli-el9-rpm/brotli.spec ~/rpmbuild/SPECS/

RUN sed -i \
    -e 's/^Version:.*/Version:        1.0.10/' \
    -e 's/^Release:.*/Release:        1%{?dist}/' \
    ~/rpmbuild/SPECS/brotli.spec \
    && curl -fL \
    -o ~/rpmbuild/SOURCES/brotli-1.0.10.tar.gz \
    https://github.com/google/brotli/archive/v1.0.10/brotli-1.0.10.tar.gz

RUN dnf builddep -y ~/rpmbuild/SPECS/brotli.spec \
    && rpmbuild -bp --define '_lto_cflags %{nil}' ~/rpmbuild/SPECS/brotli.spec


# Compile
RUN rpmbuild -ba --define '_lto_cflags %{nil}' ~/rpmbuild/SPECS/brotli.spec

# Export stage: only the built RPMs/SRPMs (use with --output type=local)
FROM scratch AS export
COPY --from=builder /root/rpmbuild/RPMS/ /RPMS/
COPY --from=builder /root/rpmbuild/SRPMS/ /SRPMS/
