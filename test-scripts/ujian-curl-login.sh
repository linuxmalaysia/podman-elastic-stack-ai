#!/bin/bash

# --- Configuration ---
USERNAME="${USERNAME:-testuser}"
PASSWORD="${PASSWORD:-}"

if [ -z "$PASSWORD" ]; then
  echo "Error: PASSWORD environment variable is not set."
  echo "Usage: PASSWORD='your_password' USERNAME='testuser' $0"
  exit 1
fi

urlencode() {
  local string="${1}"
  local length="${#string}"
  local i char
  for (( i = 0; i < length; i++ )); do
    char="${string:i:1}"
    case "${char}" in
      [a-zA-Z0-9.~_-]) printf "%s" "${char}" ;;
      *) printf "%%%02X" "'${char}" ;;
    esac
  done
}

ENCODED_USER=$(urlencode "$USERNAME")
ENCODED_PASS=$(urlencode "$PASSWORD")

TEST_URL="https://httpbin.org/basic-auth/$ENCODED_USER/$ENCODED_PASS"

# --- Encode Credentials ---
CREDENTIALS="${USERNAME}:${PASSWORD}"
BASE64_CREDENTIALS=$(echo -n "$CREDENTIALS" | base64)
AUTHORIZATION_HEADER="Authorization: Basic ${BASE64_CREDENTIALS}"

# --- Make the curl request ---
echo "Attempting to access: $TEST_URL"
curl -v -H "${AUTHORIZATION_HEADER}" "$TEST_URL"

echo ""
echo "--- Explanation ---"
echo "This script demonstrates how to use curl with a username and password for Basic Authentication."
echo "It defines a username and password, encodes them using base64, and then uses the"
echo "'Authorization' header with 'Basic' authentication scheme in the curl request."
echo "The '-v' option in curl provides verbose output, showing the headers being sent."
echo "The test URL 'https://httpbin.org/basic-auth/$USERNAME/$PASSWORD' from httpbin.org"
echo "is used, which will return a success response if the provided credentials are correct."
