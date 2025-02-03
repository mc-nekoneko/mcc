ARG JAVA_VERSION=21
FROM eclipse-temurin:${JAVA_VERSION}-jre-jammy AS base

ENV TZ=Asia/Tokyo
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

ENV LANG=ja_JP.UTF-8
RUN echo "${LANG} UTF-8" >> /etc/locale.gen && locale-gen ${LANG}

RUN apt-get update \
    && apt-get install -y git sqlite netcat \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

FROM alpine:3 AS downloader

ARG PAPERMC_APP_NAME=paper
ARG PAPERMC_APP_VERSION=latest

ENV APP_NAME=${PAPERMC_APP_NAME}
ENV APP_VERSION=${PAPERMC_APP_VERSION}

RUN apk add --no-cache --update-cache curl jq

COPY download-paper.sh /download-paper.sh
RUN chmod +x /download-paper.sh && \
    /download-paper.sh

FROM base

COPY --from=downloader /server.jar /server.env /opt/papermc/

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

ARG JVM_FLAGS=""
ENV JVM_FLAGS=${JVM_FLAGS}

COPY ./entrypoint.sh /entrypoint.sh
ENTRYPOINT [ "/bin/bash", "/entrypoint.sh" ]

# CMD ["/bin/bash", "/entrypoint.sh"]
