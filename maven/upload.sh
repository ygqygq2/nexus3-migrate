#!/bin/bash

# copy and run this script to the root of the repository directory containing files
# this script attempts to exclude uploading itself explicitly so the script name is important
# Get command line params
while getopts ":r:u:p:d:" opt; do
  case $opt in
  r)
    REPO_URL="$OPTARG"
    ;;
  u)
    USERNAME="$OPTARG"
    ;;
  p)
    PASSWORD="$OPTARG"
    ;;
  d)
    DOWNLOAD_DIR="$OPTARG"
    ;;
  esac
done

# 设置默认下载目录
if [ -z "$DOWNLOAD_DIR" ]; then
  DOWNLOAD_DIR="nexus_download"
fi

# Find and upload files from the specified download directory
find "$DOWNLOAD_DIR" -type f ! -name "$(basename "$0")" ! -path '*/\.*' | while IFS= read -r file; do
  relative_path=$(echo "$file" | sed "s|^${DOWNLOAD_DIR}/||")
  echo "Uploading ${relative_path} to ${REPO_URL}/${relative_path}..."
  curl -u "$USERNAME:$PASSWORD" -X PUT -T "$file" "${REPO_URL}/${relative_path}"
done
