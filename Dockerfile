FROM rust:slim as rust-builder
RUN apt-get update && apt-get install git libpam0g-dev -y && git clone "https://git.sr.ht/~kennylevinsen/greetd" "/greetd"
WORKDIR /greetd
RUN cargo build --release

RUN cd / && git clone "https://github.com/apognu/tuigreet" "/tuigreet"
WORKDIR /tuigreet
RUN cargo build --release

FROM ubuntu:latest as deb-builder
ARG version
RUN apt-get update && apt-get install build-essential curl jq -y && mkdir -p /tuigreet-greetd_$version/DEBIAN && mkdir -p /tuigreet-greetd_$version/usr/local/bin/ && mkdir -p /tuigreet-greetd_$version/etc/pam.d/ && mkdir -p /tuigreet-greetd_$version/etc/greetd && mkdir -p /tuigreet-greetd_$version/etc/systemd/system/
WORKDIR /
COPY --from=rust-builder /greetd/target/release/greetd /tuigreet-greetd_$version/usr/local/bin/greetd
COPY --from=rust-builder /tuigreet/target/release/tuigreet /tuigreet-greetd_$version/usr/local/bin/tuigreet
COPY greetd.service /tuigreet-greetd_$version/etc/systemd/system/greetd.service
COPY config.toml /tuigreet-greetd_$version/etc/greetd/config.toml
COPY greetd /tuigreet-greetd_$version/etc/pam.d/
COPY control /tuigreet-greetd_$version/DEBIAN/control
COPY postinst /tuigreet-greetd_$version/DEBIAN/postinst
RUN sed -i -e "s|placeholder|$version|g" /tuigreet-greetd_$version/DEBIAN/control
RUN dpkg-deb --build tuigreet-greetd_$version

FROM ubuntu:latest
COPY --from=deb-builder /tuigreet-greetd* /
CMD bash