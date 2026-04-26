#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';

const DEFAULT_TOKEN_URL = 'https://oauth2.googleapis.com/token';
const DEFAULT_API_BASE = 'https://www.googleapis.com/youtube/v3';

function parseArgs(argv) {
  const args = {
    queue: '',
    dryRun: false,
    now: '',
    graceMinutes: 0,
    max: 5,
    requirePublic: true,
  };
  for (let i = 2; i < argv.length; i += 1) {
    const a = argv[i];
    if (a === '--queue') args.queue = argv[++i] ?? '';
    else if (a === '--dry-run') args.dryRun = true;
    else if (a === '--now') args.now = argv[++i] ?? '';
    else if (a === '--grace-minutes') args.graceMinutes = Number(argv[++i] ?? 0);
    else if (a === '--max') args.max = Number(argv[++i] ?? 5);
    else if (a === '--no-require-public') args.requirePublic = false;
    else if (a === '--help' || a === '-h') {
      printHelp();
      process.exit(0);
    } else {
      throw new Error(`Unknown argument: ${a}`);
    }
  }
  if (!args.queue) throw new Error('Missing --queue <path>');
  return args;
}

function printHelp() {
  console.log(`Usage: node comment_due.mjs --queue <queue.json> [options]\n\nOptions:\n  --dry-run              Do not call YouTube API or write changes\n  --now <iso-date>       Override current time for tests\n  --grace-minutes <n>    Wait n minutes after scheduledAt before commenting\n  --max <n>              Maximum comments to post in one run (default: 5)\n  --no-require-public    Post without checking videos.list privacyStatus\n`);
}

function readJson(file) {
  return JSON.parse(fs.readFileSync(file, 'utf8'));
}

function writeJsonAtomic(file, data) {
  const tmp = `${file}.tmp`;
  fs.writeFileSync(tmp, `${JSON.stringify(data, null, 2)}\n`);
  fs.renameSync(tmp, file);
}

function env(name, required = true) {
  const value = process.env[name];
  if (required && !value) throw new Error(`Missing environment variable: ${name}`);
  return value;
}

async function fetchJson(url, options) {
  const res = await fetch(url, options);
  const text = await res.text();
  let body = null;
  try { body = text ? JSON.parse(text) : null; } catch { body = text; }
  if (!res.ok) {
    const msg = typeof body === 'string' ? body : JSON.stringify(body);
    throw new Error(`HTTP ${res.status} ${res.statusText}: ${msg}`);
  }
  return body;
}

async function getAccessToken() {
  const body = new URLSearchParams({
    client_id: env('YOUTUBE_CLIENT_ID'),
    client_secret: env('YOUTUBE_CLIENT_SECRET'),
    refresh_token: env('YOUTUBE_REFRESH_TOKEN'),
    grant_type: 'refresh_token',
  });
  const token = await fetchJson(process.env.GOOGLE_OAUTH_TOKEN_URL || DEFAULT_TOKEN_URL, {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body,
  });
  if (!token.access_token) throw new Error('OAuth response did not include access_token');
  return token.access_token;
}

async function getVideoStatus(accessToken, videoId) {
  const base = process.env.YOUTUBE_API_BASE || DEFAULT_API_BASE;
  const url = `${base}/videos?part=status,snippet&id=${encodeURIComponent(videoId)}`;
  const body = await fetchJson(url, { headers: { authorization: `Bearer ${accessToken}` } });
  const item = body.items?.[0];
  if (!item) return { exists: false };
  return {
    exists: true,
    privacyStatus: item.status?.privacyStatus ?? '',
    madeForKids: item.status?.madeForKids ?? null,
    title: item.snippet?.title ?? '',
  };
}

async function insertComment(accessToken, videoId, textOriginal) {
  const base = process.env.YOUTUBE_API_BASE || DEFAULT_API_BASE;
  const body = {
    snippet: {
      videoId,
      topLevelComment: { snippet: { textOriginal } },
    },
  };
  return fetchJson(`${base}/commentThreads?part=snippet`, {
    method: 'POST',
    headers: {
      authorization: `Bearer ${accessToken}`,
      'content-type': 'application/json',
    },
    body: JSON.stringify(body),
  });
}

function dueItems(queue, now, graceMs, max) {
  return (queue.items ?? [])
    .filter((item) => item.videoId && item.commentText && !item.commentedAt && !item.skip)
    .filter((item) => {
      const scheduled = Date.parse(item.scheduledAt || item.publishAt || '');
      return Number.isFinite(scheduled) && scheduled + graceMs <= now.getTime();
    })
    .sort((a, b) => Date.parse(a.scheduledAt || a.publishAt) - Date.parse(b.scheduledAt || b.publishAt))
    .slice(0, max);
}

async function main() {
  const args = parseArgs(process.argv);
  const queuePath = path.resolve(args.queue);
  const queue = readJson(queuePath);
  const now = args.now ? new Date(args.now) : new Date();
  if (Number.isNaN(now.getTime())) throw new Error(`Invalid --now: ${args.now}`);
  const graceMs = args.graceMinutes * 60 * 1000;
  const targets = dueItems(queue, now, graceMs, args.max);

  console.log(`Queue: ${queuePath}`);
  console.log(`Now: ${now.toISOString()}`);
  console.log(`Due uncommented items: ${targets.length}`);
  if (targets.length === 0) return;

  if (args.dryRun) {
    for (const item of targets) {
      console.log(`[dry-run] would comment: ${item.slug ?? item.videoId} (${item.videoId}) scheduledAt=${item.scheduledAt}`);
    }
    return;
  }

  const accessToken = await getAccessToken();
  let changed = false;
  for (const item of targets) {
    console.log(`Processing ${item.slug ?? item.videoId} (${item.videoId})`);
    try {
      if (args.requirePublic) {
        const status = await getVideoStatus(accessToken, item.videoId);
        item.lastCheckedAt = new Date().toISOString();
        item.lastVideoStatus = status;
        changed = true;
        if (!status.exists) {
          console.log('  skip: video not found');
          continue;
        }
        if (status.privacyStatus !== 'public') {
          console.log(`  skip: privacyStatus=${status.privacyStatus}`);
          continue;
        }
      }
      const inserted = await insertComment(accessToken, item.videoId, item.commentText);
      item.commentedAt = new Date().toISOString();
      item.commentThreadId = inserted.id ?? null;
      item.commentId = inserted.snippet?.topLevelComment?.id ?? null;
      item.status = 'commented';
      item.lastError = null;
      changed = true;
      console.log(`  commented: thread=${item.commentThreadId ?? 'unknown'}`);
      writeJsonAtomic(queuePath, queue);
    } catch (err) {
      item.lastError = { at: new Date().toISOString(), message: err.message };
      changed = true;
      console.error(`  error: ${err.message}`);
      writeJsonAtomic(queuePath, queue);
    }
  }
  if (changed) writeJsonAtomic(queuePath, queue);
}

main().catch((err) => {
  console.error(err.stack || err.message);
  process.exit(1);
});
