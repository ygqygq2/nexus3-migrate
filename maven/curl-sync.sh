#!/bin/bash

# Nexus 仓库的基础 URL
SOURCE_NEXUS_BASE_URL="http://nexus-server:8081"
TARGET_NEXUS_BASE_URL="http://nexus-server:8082"

# 搜索的仓库
REPOSITORY="maven-snapshots"
TARGET_REPOSITORY="maven-snapshots"

# 组ID
GROUP="com.github"

# 构造搜索 API 的 URL
SEARCH_URL="${SOURCE_NEXUS_BASE_URL}/service/rest/v1/search?repository=${REPOSITORY}&group=${GROUP}"

# 用于保存结果的文件
OUTPUT_FILE="packages_list.txt"

# 本地下载目录
DOWNLOAD_DIR="./nexus_download"

# Nexus 目标仓库的认证信息
NEXUS_USER="admin"
NEXUS_PASSWORD="密码"

# 初始化 continuationToken
continuationToken=""

# 创建下载目录
mkdir -p "$DOWNLOAD_DIR"

# 清空结果文件
>"$OUTPUT_FILE"

# 循环请求所有页面
while :; do
    # 构造带有 continuationToken 的请求 URL（如果有的话）
    URL="${SEARCH_URL}"
    if [[ -n $continuationToken ]]; then
        URL="${URL}&continuationToken=${continuationToken}"
    fi

    # 发送请求
    response=$(curl -s "$URL")

    # 解析并保存结果
    echo "$response" | jq -r '.items[] | .assets[] | .downloadUrl' >>"$OUTPUT_FILE"

    # 检查是否还有更多页面
    continuationToken=$(echo "$response" | jq -r '.continuationToken // empty')
    [[ -z $continuationToken ]] && break # 如果没有 continuationToken，则退出循环
done

# 下载文件并保存到本地下载目录
echo "Downloading packages from source Nexus repository..."
while IFS= read -r download_url; do
    # 获取文件路径
    file_path="${DOWNLOAD_DIR}/$(echo "$download_url" | sed "s|${SOURCE_NEXUS_BASE_URL}/repository/${REPOSITORY}/||")"
    # 创建目录结构
    mkdir -p "$(dirname "$file_path")"
    # 下载文件
    echo "Downloading ${download_url}..."
    curl -u "$NEXUS_USER:$NEXUS_PASSWORD" -s "$download_url" -o "$file_path"

    # 下载 maven-metadata.xml 及其相关文件
    dir=$(dirname "$file_path")
    metadata_files=("maven-metadata.xml" "maven-metadata.xml.md5" "maven-metadata.xml.sha1")
    for metadata_file in "${metadata_files[@]}"; do
        metadata_url="${SOURCE_NEXUS_BASE_URL}/repository/${REPOSITORY}/$(echo "$dir" | sed "s|^${DOWNLOAD_DIR}/||")/${metadata_file}"
        if curl -u "$NEXUS_USER:$NEXUS_PASSWORD" -s --head --fail "$metadata_url" >/dev/null; then
            echo "Downloading ${metadata_url}..."
            curl -u "$NEXUS_USER:$NEXUS_PASSWORD" -s "$metadata_url" -o "${dir}/${metadata_file}"
        fi
    done
done <"$OUTPUT_FILE"

# 下载 archetype-catalog.xml 及其校验文件
echo "Downloading archetype-catalog.xml files..."
archetype_catalog_files=("archetype-catalog.xml" "archetype-catalog.xml.md5" "archetype-catalog.xml.sha1" "archetype-catalog.xml.sha256" "archetype-catalog.xml.sha512")
for file in "${archetype_catalog_files[@]}"; do
    archetype_catalog_url="${SOURCE_NEXUS_BASE_URL}/repository/${REPOSITORY}/${file}"
    if curl -u "$NEXUS_USER:$NEXUS_PASSWORD" -s --head --fail "$archetype_catalog_url" >/dev/null; then
        echo "Downloading ${archetype_catalog_url}..."
        curl -u "$NEXUS_USER:$NEXUS_PASSWORD" -s "$archetype_catalog_url" -o "${DOWNLOAD_DIR}/${file}"
    fi
done

# 上传文件到目标 Nexus 仓库
echo "Uploading packages to target Nexus repository..."
find "$DOWNLOAD_DIR" -type f | while IFS= read -r file; do
    # 获取相对路径
    relative_path=$(echo "$file" | sed "s|^${DOWNLOAD_DIR}/||")
    # 构造上传 URL
    upload_url="${TARGET_NEXUS_BASE_URL}/repository/${TARGET_REPOSITORY}/${relative_path}"
    # 上传文件
    echo "Uploading ${file} to ${upload_url}..."
    curl -u "$NEXUS_USER:$NEXUS_PASSWORD" -X PUT -T "$file" "$upload_url"
done

echo "Sync completed."
