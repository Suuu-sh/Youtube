#!/usr/bin/env bash
set -euo pipefail

cd /Users/yota/Projects/Automation/Youtube/雑学ニキ

mode="${1:-}"
case "$mode" in
  run)
    ruby scripts/zatsugaku_inventory.rb validate
    # Keep a single automation idempotent: only the 04:00 hour selects today's stock,
    # while every run retries upload/comment work that is already due.
    if [[ "$(TZ=Asia/Tokyo date +%H)" == "04" ]]; then
      ruby scripts/zatsugaku_inventory.rb plan --date today
    fi
    ruby scripts/zatsugaku_inventory.rb upload-due
    ruby scripts/zatsugaku_inventory.rb comment-due
    ;;
  daily-upload)
    ruby scripts/zatsugaku_inventory.rb validate
    ruby scripts/zatsugaku_inventory.rb plan --date today
    ruby scripts/zatsugaku_inventory.rb upload-due
    ;;
  upload-retry)
    ruby scripts/zatsugaku_inventory.rb validate
    ruby scripts/zatsugaku_inventory.rb upload-due
    ;;
  comment-due)
    ruby scripts/zatsugaku_inventory.rb validate
    ruby scripts/zatsugaku_inventory.rb comment-due
    ;;
  dry-run)
    ruby scripts/zatsugaku_inventory.rb validate
    ruby scripts/zatsugaku_inventory.rb plan --date today --dry-run || true
    ruby scripts/zatsugaku_inventory.rb upload-due --dry-run
    ruby scripts/zatsugaku_inventory.rb comment-due --dry-run
    ;;
  *)
    echo "Usage: $0 {run|daily-upload|upload-retry|comment-due|dry-run}" >&2
    exit 2
    ;;
esac
