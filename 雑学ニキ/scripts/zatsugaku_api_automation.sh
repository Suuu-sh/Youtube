#!/usr/bin/env bash
set -euo pipefail

cd /Users/yota/Projects/Automation/Youtube/雑学ニキ

# Optional local-only secret file. Do not commit actual credentials.
# Expected keys: YOUTUBE_CLIENT_ID, YOUTUBE_CLIENT_SECRET, YOUTUBE_REFRESH_TOKEN.
secret_env="${ZATSUGAKU_YOUTUBE_ENV:-/Users/yota/.codex/secrets/youtube_zatsugaku_api.env}"
if [[ -f "$secret_env" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$secret_env"
  set +a
fi

# Upload can be run after video creation. Override with ZATSUGAKU_PLAN_DATE=YYYY-MM-DD;
# the combined automation should pass the date returned by next-missing-set.
plan_date="${ZATSUGAKU_PLAN_DATE:-tomorrow}"

mode="${1:-}"
case "$mode" in
  upload-schedule|run|plan-2000)
    ruby scripts/zatsugaku_inventory.rb validate
    ruby scripts/zatsugaku_inventory.rb plan --date "$plan_date"
    ruby scripts/zatsugaku_inventory.rb upload-due
    ;;
  upload-retry)
    ruby scripts/zatsugaku_inventory.rb validate
    ruby scripts/zatsugaku_inventory.rb upload-due
    ;;
  dry-run)
    ruby scripts/zatsugaku_inventory.rb validate
    ruby scripts/zatsugaku_inventory.rb plan --date "$plan_date" --dry-run
    ruby scripts/zatsugaku_inventory.rb upload-due --dry-run
    ruby scripts/zatsugaku_inventory.rb next-missing-set --date today
    ;;
  *)
    echo "Usage: $0 {upload-schedule|run|plan-2000|upload-retry|dry-run}" >&2
    exit 2
    ;;
esac
