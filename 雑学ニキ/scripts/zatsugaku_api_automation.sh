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

mode="${1:-}"
case "$mode" in
  run|plan-0400|next-day-upload-0400)
    ruby scripts/zatsugaku_daily_scrape.rb --date today
    ruby scripts/zatsugaku_inventory.rb validate
    # 04:00 hour schedules today's five posts from existing stock.
    if [[ "$(TZ=Asia/Tokyo date +%H)" == "04" ]]; then
      ruby scripts/zatsugaku_inventory.rb plan --date today
    fi
    ruby scripts/zatsugaku_inventory.rb upload-due
    # Then report the next missing five-video set for stock replenishment.
    # Video creation happens in the Codex automation prompt after this target is known.
    ruby scripts/zatsugaku_inventory.rb next-missing-set --date today
    ;;
  comment-0735|comment-1205|comment-1805|comment-2105|comment-2505|comment-due)
    # Comments are now intentionally disabled. Keep these modes as no-ops so
    # any remaining scheduled automation jobs do not fail before they are removed.
    echo "Comment API disabled; no-op."
    ;;
  upload-retry)
    ruby scripts/zatsugaku_inventory.rb validate
    ruby scripts/zatsugaku_inventory.rb upload-due
    ;;
  sync-metadata)
    ruby scripts/zatsugaku_inventory.rb validate
    ruby scripts/zatsugaku_inventory.rb sync-metadata
    ;;
  dry-run)
    ruby scripts/zatsugaku_daily_scrape.rb --date today --dry-run
    ruby scripts/zatsugaku_inventory.rb validate
    ruby scripts/zatsugaku_inventory.rb next-missing-set --date today
    ruby scripts/zatsugaku_inventory.rb upload-due --dry-run
    ruby scripts/zatsugaku_inventory.rb sync-metadata --dry-run
    ;;
  *)
    echo "Usage: $0 {run|plan-0400|next-day-upload-0400|comment-0735|comment-1205|comment-1805|comment-2105|comment-2505|comment-due|upload-retry|sync-metadata|dry-run}" >&2
    exit 2
    ;;
esac
