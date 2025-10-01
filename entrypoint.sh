#!/usr/bin/env bash
set -eEuo pipefail

# Start simple HTTP health check server on port 8080
health_check_server() {
  while true; do
    echo -e "HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nOK" | nc -l -p 8080 -q 1 > /dev/null 2>&1
  done
}

# Start health check in background
health_check_server &
HEALTH_PID=$!

if [ -z "${TOKEN:-}" ]
then
  echo "TOKEN is required"
  exit 1
fi

if [ -n "${ORG:-}" ]
then
  API_PATH=orgs/${ORG}
  CONFIG_PATH=${ORG}
elif [ -n "${OWNER:-}" ] && [ -n "${REPO:-}" ]
then
  API_PATH=repos/${OWNER}/${REPO}
  CONFIG_PATH=${OWNER}/${REPO}
else
  echo "[ORG] or [OWNER and REPO] is required"
  exit 1
fi

RUNNER_TOKEN=$(curl -s -X POST -H "authorization: token ${TOKEN}" "https://api.github.com/${API_PATH}/actions/runners/registration-token" | jq -r .token)

cleanup() {
  kill $HEALTH_PID 2>/dev/null || true
  ./config.sh remove --token "${RUNNER_TOKEN}"
}

sudo RUNNER_ALLOW_RUNASROOT=true ./config.sh \
  --url "https://github.com/${CONFIG_PATH}" \
  --token "${RUNNER_TOKEN}" \
  --name "${NAME:-$(hostname)}" \
  --runnergroup self-hosted
  --unattended

trap 'cleanup' SIGTERM

sudo RUNNER_ALLOW_RUNASROOT=true ./run.sh "$@" &
wait $!
