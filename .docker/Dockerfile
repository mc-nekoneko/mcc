ARG JAVA_VERSION=21
FROM eclipse-temurin:${JAVA_VERSION}-jre-jammy as base

ENV TZ=Asia/Tokyo
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

ENV LANG=ja_JP.UTF-8
RUN echo "${LANG} UTF-8" >> /etc/locale.gen && locale-gen ${LANG}

RUN apt-get update \
    && apt-get install -y git sqlite netcat \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

FROM alpine:3 as downloader

ARG PAPERMC_APP_NAME=paper
ARG PAPERMC_APP_VERSION=latest

ENV APP_NAME=${PAPERMC_APP_NAME}
ENV APP_VERSION=${PAPERMC_APP_VERSION}

RUN apk add --no-cache --update-cache curl jq
RUN <<EOF
    set -o errexit -o pipefail -o nounset

    if [ "${APP_VERSION}" = "latest" ]; then
        APP_VERSION=$(curl -s "https://papermc.io/api/v2/projects/${APP_NAME}" | jq -r '.versions[-1]')
    fi

    echo "Using ${APP_NAME} version ${APP_VERSION}"
    JSON=$(curl -sSLf https://api.papermc.io/v2/projects/${APP_NAME}/versions/${APP_VERSION}/builds | jq '.builds[-1]')

    BUILD=$(echo "${JSON}" | jq -r '.build')
    SHA256=$(echo "${JSON}" | jq -r '.downloads.application.sha256')
    FILE=$(echo "${JSON}" | jq -r '.downloads.application.name')

    URL="https://papermc.io/api/v2/projects/${APP_NAME}/versions/${APP_VERSION}/builds/${BUILD}/downloads/${FILE}"


    curl -sSLf -o /server.jar ${URL}
    echo "${SHA256} /server.jar" | sha256sum -c -

    echo "APP=${APP_NAME}" > /server.env
    echo "VERSION=${APP_VERSION}" >> /server.env
    echo "BUILD=${BUILD}" >> /server.env
    echo "SHA256=${SHA256}" >> /server.env
EOF

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
