FROM rust:slim AS rust-builder
RUN <<EOF
    apt-get update
    apt-get install git libpam0g-dev -y
    git clone "https://git.sr.ht/~kennylevinsen/greetd" "/greetd"
EOF

FROM rust-builder AS greetd-builder
WORKDIR /greetd
RUN cargo build --release

FROM rust-builder AS tuigreet-builder
RUN cd / && git clone "https://github.com/apognu/tuigreet" "/tuigreet"

WORKDIR /tuigreet
RUN cargo build --release

FROM ubuntu:latest AS deb-builder
ARG VERSION

RUN <<EOF
    apt-get update
    apt-get install build-essential curl jq -y
    mkdir -p /tuigreet-greetd_$VERSION/DEBIAN
    mkdir -p /tuigreet-greetd_$VERSION/usr/local/bin/
    mkdir -p /tuigreet-greetd_$VERSION/etc/pam.d/
    mkdir -p /tuigreet-greetd_$VERSION/etc/greetd
    mkdir -p /tuigreet-greetd_$VERSION/etc/systemd/system/
EOF

COPY --from=greetd-builder /greetd/target/release/greetd /tuigreet-greetd_$VERSION/usr/local/bin/greetd
COPY --from=tuigreet-builder /tuigreet/target/release/tuigreet /tuigreet-greetd_$VERSION/usr/local/bin/tuigreet
COPY greetd.service /tuigreet-greetd_$VERSION/etc/systemd/system/greetd.service
COPY config.toml /tuigreet-greetd_$VERSION/etc/greetd/config.toml
COPY greetd /tuigreet-greetd_$VERSION/etc/pam.d/
COPY control /tuigreet-greetd_$VERSION/DEBIAN/control
COPY postinst /tuigreet-greetd_$VERSION/DEBIAN/postinst

RUN sed -i -e "s|placeholder|$VERSION|g" /tuigreet-greetd_$VERSION/DEBIAN/control
RUN dpkg-deb --build tuigreet-greetd_$VERSION

FROM alpine:latest AS final
ARG VERSION
COPY --from=deb-builder /tuigreet-greetd_$VERSION.deb /tuigreet-greetd_$VERSION.deb
CMD ["yes"]
