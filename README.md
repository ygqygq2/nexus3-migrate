# nexus3-migrate
maven/npm repository to another nexus3

## Usage
Modify `curl-sync.sh` to set nexus url, username and passowrd

```bash
sh curl-sync.sh
```

## maven python script

`nexus3_exporter.py`
https://github.com/LoadingByte/nexus3-exporter
to download maven2 repository data
`upload.sh` to upload data to another nexus3
