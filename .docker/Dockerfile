ARG JAVA_IMAGE
FROM ${JAVA_IMAGE} AS base

ENV TZ=Asia/Tokyo
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

ENV LANG=ja_JP.UTF-8
RUN apt-get update \
    && apt-get install -y --no-install-recommends locales netcat-openbsd sqlite3 \
    && echo "${LANG} UTF-8" >> /etc/locale.gen \
    && locale-gen ${LANG} \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

FROM alpine:3.22 AS downloader

ARG PAPERMC_DOWNLOAD_URL
ARG PAPERMC_DOWNLOAD_SHA256

RUN apk add --no-cache ca-certificates curl bash
COPY scripts/download-papermc.sh /usr/local/bin/download-papermc
RUN /usr/local/bin/download-papermc "$PAPERMC_DOWNLOAD_URL" "$PAPERMC_DOWNLOAD_SHA256" /server.jar

FROM base

ARG PAPERMC_PROJECT
ARG PAPERMC_VERSION
ARG PAPERMC_BUILD
ARG PAPERMC_DOWNLOAD_SHA256
ARG JVM_FLAGS=""

COPY --from=downloader /server.jar /opt/papermc/server.jar
RUN printf 'APP=%s\nVERSION=%s\nBUILD=%s\nSHA256=%s\n' \
      "$PAPERMC_PROJECT" "$PAPERMC_VERSION" "$PAPERMC_BUILD" "$PAPERMC_DOWNLOAD_SHA256" \
      > /opt/papermc/server.env

RUN adduser --gecos "" --disabled-password --home /home/minecraft minecraft

USER minecraft
ENV USER=minecraft \
    HOME=/home/minecraft

WORKDIR /home/minecraft
VOLUME /home/minecraft

EXPOSE 25565

ENV SERVER_JARFILE=/opt/papermc/server.jar
ENV SERVER_MEMORY=4G
ENV SERVER_ARGS=""

ENV JVM_FLAGS=${JVM_FLAGS}

COPY .docker/entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
