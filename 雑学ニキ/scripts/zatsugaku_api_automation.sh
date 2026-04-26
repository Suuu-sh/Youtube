#!/usr/bin/env bash
set -euo pipefail

cd /Users/yota/Projects/Automation/Youtube/雑学ニキ

mode="${1:-}"
case "$mode" in
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
    ruby scripts/zatsugaku_inventory.rb plan --date today --dry-run
    ruby scripts/zatsugaku_inventory.rb upload-due --dry-run
    ruby scripts/zatsugaku_inventory.rb comment-due --dry-run
    ;;
  *)
    echo "Usage: $0 {daily-upload|upload-retry|comment-due|dry-run}" >&2
    exit 2
    ;;
esac
