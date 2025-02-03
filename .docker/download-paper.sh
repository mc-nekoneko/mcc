#!/bin/sh

set -e  # エラー時に即座に終了

# 必要な環境変数のチェック
if [ -z "${APP_NAME}" ] || [ -z "${APP_VERSION}" ]; then
    echo "Error: APP_NAME and APP_VERSION must be set"
    exit 1
fi

# API基本URL
API_BASE="https://api.papermc.io/v2"

# APIリクエストのヘルパー関数
fetch_json() {
    curl -sSLf "$1"
}

# メイン処理
main() {
    # プロジェクト情報の取得
    PROJECT_INFO=$(fetch_json "${API_BASE}/projects/${APP_NAME}")

    # latestの場合は最新バージョンを取得
    if [ "${APP_VERSION}" = "latest" ]; then
        APP_VERSION=$(echo "${PROJECT_INFO}" | jq -r '.versions[-1]')
        echo "Latest version resolved to: ${APP_VERSION}"
    fi

    echo "Using ${APP_NAME} version ${APP_VERSION}"

    # バージョン情報の取得とビルド番号の解決
    VERSION_INFO=$(fetch_json "${API_BASE}/projects/${APP_NAME}/versions/${APP_VERSION}")
    LATEST_BUILD=$(echo "${VERSION_INFO}" | jq -r '.builds[-1]')

    # ビルド情報の取得
    BUILD_INFO=$(fetch_json "${API_BASE}/projects/${APP_NAME}/versions/${APP_VERSION}/builds/${LATEST_BUILD}")
    
    # 必要な情報の抽出
    BUILD=$(echo "${BUILD_INFO}" | jq -r '.build')
    FILENAME=$(echo "${BUILD_INFO}" | jq -r '.downloads.application.name')
    SHA256=$(echo "${BUILD_INFO}" | jq -r '.downloads.application.sha256')

    # ダウンロードURLの構築
    DOWNLOAD_URL="${API_BASE}/projects/${APP_NAME}/versions/${APP_VERSION}/builds/${BUILD}/downloads/${FILENAME}"

    # サーバーJARのダウンロードと検証
    echo "Downloading from: ${DOWNLOAD_URL}"
    if ! curl -sSLf -o /server.jar "${DOWNLOAD_URL}"; then
        echo "Error: Failed to download server jar"
        exit 1
    fi

    # チェックサムの検証
    if ! echo "${SHA256} /server.jar" | sha256sum -c -; then
        echo "Error: Checksum verification failed"
        rm -f /server.jar
        exit 1
    fi

    # 環境情報の保存
    cat > /server.env << EOL
APP=${APP_NAME}
VERSION=${APP_VERSION}
BUILD=${BUILD}
SHA256=${SHA256}
EOL

    echo "Successfully downloaded and verified server.jar"
}

main