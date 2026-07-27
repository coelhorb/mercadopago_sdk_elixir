#!/usr/bin/env bash

set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
secret_file="${project_root}/.env.integration"

if [[ ! -f "${secret_file}" ]]; then
  echo "Missing .env.integration. Copy .env.integration.example and add a test Access Token." >&2
  exit 1
fi

set -a
# shellcheck disable=SC1090
source "${secret_file}"
set +a

if [[ -z "${ACCESS_TOKEN:-}" ]]; then
  echo "ACCESS_TOKEN is empty in .env.integration." >&2
  exit 1
fi

cd "${project_root}"
exec mix test test/mercadopago/integration --include integration
