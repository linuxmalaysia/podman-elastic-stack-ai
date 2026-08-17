#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMP_CREDENTIALS_FILE="${TEMP_CREDENTIALS_FILE:-${SCRIPT_DIR}/../elk-wolfi/temp_credentials.txt}"

if [ -z "${ESPASSWORD}" ] && [ -f "${TEMP_CREDENTIALS_FILE}" ]; then
  ESPASSWORD=$(grep "Elastic password set to:" "${TEMP_CREDENTIALS_FILE}" | sed 's/.*Elastic password set to: //' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
fi

if [ -z "${ESPASSWORD}" ]; then
  echo "Error: ESPASSWORD is not set and could not be found in ${TEMP_CREDENTIALS_FILE}."
  echo "Usage: ESPASSWORD='your_password' $0"
  exit 1
fi

CERT_PATH="${CERT_PATH:-/root/elastic_stack/podman-elastic-stack/elk-wolfi/certs/http_ca.crt}"
/usr/bin/curl --cacert "${CERT_PATH}" -u "elastic:${ESPASSWORD}" https://localhost:9200
