#!/bin/bash

# Nexus 服务器信息
SOURCE_NEXUS_URL="http://nexus-server:8081"
TARGET_NEXUS_URL="http://nexus-server:8082"
NEXUS_USER="admin"
NEXUS_PASSWORD="密码"
NEXUS_EMAIL="your-email@example.com" # 请替换为你的电子邮件地址

# 仓库名称
SOURCE_REPO="npm-hosted"
TARGET_REPO="npm-hosted"

# 本地备份目录
BACKUP_DIR="./npm_backup"

# 创建备份目录
mkdir -p "$BACKUP_DIR"

# 获取 npm 包列表并处理分页
echo "Fetching npm package list from source Nexus repository..."
CONTINUATION_TOKEN=""
while :; do
  if [ -z "$CONTINUATION_TOKEN" ]; then
    URL="${SOURCE_NEXUS_URL}/service/rest/v1/components?repository=${SOURCE_REPO}"
  else
    URL="${SOURCE_NEXUS_URL}/service/rest/v1/components?repository=${SOURCE_REPO}&continuationToken=${CONTINUATION_TOKEN}"
  fi

  RESPONSE=$(curl -u "$NEXUS_USER:$NEXUS_PASSWORD" -X GET "$URL")
  echo "$RESPONSE" | jq -r '.items[] | .assets[] | select(.path | endswith(".tgz")) | .path' >>npm_packages.txt
  CONTINUATION_TOKEN=$(echo "$RESPONSE" | jq -r '.continuationToken')

  if [ "$CONTINUATION_TOKEN" == "null" ]; then
    break
  fi
done

# 下载文件并保存到本地备份目录
echo "Downloading npm packages from source Nexus repository..."
while IFS= read -r package_path; do
  # 创建目录结构
  mkdir -p "${BACKUP_DIR}/$(dirname "${package_path}")"
  # 下载包文件
  echo "Downloading ${package_path}..."
  curl -u "$NEXUS_USER:$NEXUS_PASSWORD" -X GET "${SOURCE_NEXUS_URL}/repository/${SOURCE_REPO}/${package_path}" -o "${BACKUP_DIR}/${package_path}"
done <npm_packages.txt

# 准备 ~/.npmrc 文件
echo "Preparing ~/.npmrc file..."
echo "registry=${TARGET_NEXUS_URL}/repository/${TARGET_REPO}/" >~/.npmrc
echo "email=${NEXUS_EMAIL}" >>~/.npmrc
auth=$(echo -n "$NEXUS_USER:$NEXUS_PASSWORD" | base64)
echo "//${TARGET_NEXUS_URL}/repository/${TARGET_REPO}//:_auth=${auth}" >>~/.npmrc

# 上传包文件到目标 Nexus 仓库
echo "Uploading npm packages to target Nexus repository..."
find "$BACKUP_DIR" -type f -not -path '*/\.*' -name '*.tgz' | while IFS= read -r file; do
  echo "Publishing ${file}..."
  npm publish "$file" --registry "${TARGET_NEXUS_URL}/repository/${TARGET_REPO}/"
done

# 清理下载的文件列表
rm npm_packages.txt

echo "Backup and upload completed."
