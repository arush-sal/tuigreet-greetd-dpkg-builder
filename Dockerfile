FROM rust:slim as rust-builder
RUN apt-get update && apt-get install git libpam0g-dev -y && git clone "https://git.sr.ht/~kennylevinsen/greetd" "/greetd"
WORKDIR /greetd
RUN cargo build --release

RUN cd / && git clone "https://github.com/apognu/tuigreet" "/tuigreet"
WORKDIR /tuigreet
RUN cargo build --release

FROM ubuntu:latest as deb-builder
ARG VERSION
RUN apt-get update && apt-get install build-essential curl jq -y && mkdir -p /tuigreet-greetd_$VERSION/DEBIAN && mkdir -p /tuigreet-greetd_$VERSION/usr/local/bin/ && mkdir -p /tuigreet-greetd_$VERSION/etc/pam.d/ && mkdir -p /tuigreet-greetd_$VERSION/etc/greetd && mkdir -p /tuigreet-greetd_$VERSION/etc/systemd/system/
WORKDIR /
COPY --from=rust-builder /greetd/target/release/greetd /tuigreet-greetd_$VERSION/usr/local/bin/greetd
COPY --from=rust-builder /tuigreet/target/release/tuigreet /tuigreet-greetd_$VERSION/usr/local/bin/tuigreet
COPY greetd.service /tuigreet-greetd_$VERSION/etc/systemd/system/greetd.service
COPY config.toml /tuigreet-greetd_$VERSION/etc/greetd/config.toml
COPY greetd /tuigreet-greetd_$VERSION/etc/pam.d/
COPY control /tuigreet-greetd_$VERSION/DEBIAN/control
COPY postinst /tuigreet-greetd_$VERSION/DEBIAN/postinst
RUN sed -i -e "s|placeholder|$VERSION|g" /tuigreet-greetd_$VERSION/DEBIAN/control
RUN dpkg-deb --build tuigreet-greetd_$VERSION

FROM alpine:latest
ARG VERSION
ARG TOKEN

ENV RELEASE_SCRIPT_URL="https://gist.githubusercontent.com/arush-sal/f169e7477809ee025c4da1aa0f40b029/raw/ef0e431fc04fecddc766b63f95c5c8aa87d1f552/create-github-release.sh"
ENV ASSEST_SCRIPT_URL="https://gist.githubusercontent.com/stefanbuck/ce788fee19ab6eb0b4447a85fc99f447/raw/dbadd7d310ce8446de89c4ffdf1db0b400d0f6c3/upload-github-release-asset.sh"

COPY --from=deb-builder /tuigreet-greetd* /

RUN apk --no-cache add curl
RUN curl $RELEASE_SCRIPT_URL | sh
RUN export ASSEST=$(find / -iname *.deb) && \
    export github_api_token=$TOKEN && \
    export owner=arush-sal && \
    export repo=tuigreet-greetd-dpkg-builder && \
    export tag="$VERSION" && \
    export filename=$ASSEST && \
    echo $filename && sleep 2 && \
    curl $ASSEST_SCRIPT_URL | sh
CMD sh