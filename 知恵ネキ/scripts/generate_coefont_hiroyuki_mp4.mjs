#!/usr/bin/env node

import fs from 'fs';
import path from 'path';
import process from 'process';

const [, , portArg, outputDir, textFile, outputNameArg] = process.argv;

if (!portArg || !outputDir || !textFile) {
  console.error('Usage: node generate_coefont_hiroyuki_mp4.mjs <port> <output-dir> <text-file> [output-mp4-name]');
  process.exit(1);
}

const port = Number(portArg);
const text = fs.readFileSync(textFile, 'utf8').trim();
const outputName = outputNameArg || 'coefont_hiroyuki_voice.mp4';

if (!text) {
  throw new Error(`Text file is empty: ${textFile}`);
}

fs.mkdirSync(outputDir, { recursive: true });

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

class CDPClient {
  constructor(wsUrl) {
    this.ws = new WebSocket(wsUrl);
    this.nextId = 1;
    this.pending = new Map();
  }

  async connect() {
    await new Promise((resolve, reject) => {
      this.ws.addEventListener('open', resolve, { once: true });
      this.ws.addEventListener('error', reject, { once: true });
    });
    this.ws.addEventListener('message', (event) => {
      const msg = JSON.parse(String(event.data));
      if (!msg.id) return;
      const pending = this.pending.get(msg.id);
      if (!pending) return;
      this.pending.delete(msg.id);
      if (msg.error) pending.reject(new Error(msg.error.message));
      else pending.resolve(msg.result);
    });
  }

  send(method, params = {}) {
    const id = this.nextId++;
    return new Promise((resolve, reject) => {
      this.pending.set(id, { resolve, reject });
      this.ws.send(JSON.stringify({ id, method, params }));
    });
  }

  close() {
    this.ws.close();
  }
}

async function httpJson(url, opts) {
  const res = await fetch(url, opts);
  if (!res.ok) throw new Error(`HTTP ${res.status} for ${url}`);
  return res.json();
}

async function createTarget(port, url) {
  try {
    return await httpJson(`http://127.0.0.1:${port}/json/new?${encodeURIComponent(url)}`, { method: 'PUT' });
  } catch {
    return await httpJson(`http://127.0.0.1:${port}/json/new?${encodeURIComponent(url)}`);
  }
}

async function evalValue(client, expression) {
  const result = await client.send('Runtime.evaluate', {
    expression,
    returnByValue: true,
    awaitPromise: true,
  });
  return result.result?.value;
}

async function waitFor(label, fn, timeoutMs = 180000, intervalMs = 1000) {
  const started = Date.now();
  while (Date.now() - started < timeoutMs) {
    const value = await fn().catch(() => null);
    if (value) return value;
    await sleep(intervalMs);
  }
  throw new Error(`Timed out waiting for ${label}`);
}

function listMp4s(dir) {
  if (!fs.existsSync(dir)) return [];
  return fs
    .readdirSync(dir)
    .filter((name) => name.toLowerCase().endsWith('.mp4') && !name.endsWith('.crdownload'))
    .map((name) => path.join(dir, name));
}

async function downloadUrlToFile(url, filePath) {
  const res = await fetch(url);
  if (!res.ok) {
    throw new Error(`HTTP ${res.status} while downloading CoeFont video`);
  }
  const buffer = Buffer.from(await res.arrayBuffer());
  fs.writeFileSync(filePath, buffer);
}

async function main() {
  const before = new Set(listMp4s(outputDir));
  const target = await createTarget(port, 'https://coefont.cloud/maker/hiroyuki');
  const client = new CDPClient(target.webSocketDebuggerUrl);
  await client.connect();

  try {
    await client.send('Page.enable');
    await client.send('Runtime.enable');
    await client.send('Browser.setDownloadBehavior', {
      behavior: 'allow',
      downloadPath: outputDir,
    }).catch(async () => {
      await client.send('Page.setDownloadBehavior', {
        behavior: 'allow',
        downloadPath: outputDir,
      });
    });

    await waitFor('CoeFont maker page', async () =>
      evalValue(
        client,
        `(() => document.querySelector('textarea') && document.body.innerText.includes('動画を生成'))()`
      )
    );

    console.log('Setting CoeFont text...');
    const textSetResult = await evalValue(
      client,
      `(() => {
        const textarea = document.querySelector('textarea');
        const text = ${JSON.stringify(text)};
        const setter = Object.getOwnPropertyDescriptor(HTMLTextAreaElement.prototype, 'value')?.set;
        textarea.focus();
        if (setter) setter.call(textarea, text);
        else textarea.value = text;
        textarea.dispatchEvent(new KeyboardEvent('keydown', { bubbles: true, key: 'a' }));
        textarea.dispatchEvent(new InputEvent('input', { bubbles: true, inputType: 'insertText', data: text }));
        textarea.dispatchEvent(new Event('change', { bubbles: true }));
        textarea.dispatchEvent(new KeyboardEvent('keyup', { bubbles: true, key: 'a' }));
        textarea.blur();
        return textarea.value;
      })()`
    );
    if (textSetResult !== text) {
      throw new Error(`Could not set CoeFont textarea. Expected ${text.length} chars, got ${String(textSetResult).length} chars.`);
    }

    console.log('Generating CoeFont video...');
    const clickedGenerate = await evalValue(
      client,
      `(() => {
        const buttons = [...document.querySelectorAll('button, [role="button"]')];
        const btn = buttons.find((el) => (el.innerText || '').trim() === '動画を生成');
        if (!btn) return false;
        btn.click();
        return true;
      })()`
    );
    if (!clickedGenerate) throw new Error('Could not click 動画を生成');

    await waitFor('download button enabled', async () =>
      evalValue(
        client,
        `(() => {
          const buttons = [...document.querySelectorAll('button, [role="button"]')];
          const btn = buttons.find((el) => (el.innerText || '').includes('ダウンロード'));
          return !!btn && !btn.disabled && btn.getAttribute('aria-disabled') !== 'true';
        })()`
      ),
      240000,
      1500
    );

    const videoSrc = await waitFor('generated video URL', async () =>
      evalValue(
        client,
        `(() => {
          const videos = [...document.querySelectorAll('video')];
          const video = videos.find((v) => (v.currentSrc || v.src || '').includes('.mp4'));
          return video ? (video.currentSrc || video.src) : '';
        })()`
      ),
      60000,
      1000
    );

    const finalPath = path.join(outputDir, outputName);
    console.log('Downloading CoeFont mp4 from generated video URL...');
    await downloadUrlToFile(videoSrc, finalPath);

    if (fs.statSync(finalPath).size > 0) {
      console.log(`Downloaded: ${finalPath}`);
      return;
    }

    console.log('Generated URL download was empty; trying page download button...');
    const clickedDownload = await evalValue(
      client,
      `(() => {
        const buttons = [...document.querySelectorAll('button, [role="button"]')];
        const btn = buttons.find((el) => (el.innerText || '').includes('ダウンロード'));
        if (!btn || btn.disabled) return false;
        btn.click();
        return true;
      })()`
    );
    if (!clickedDownload) throw new Error('Could not click ダウンロード(mp4)');

    const downloaded = await waitFor('downloaded mp4', async () => {
      const current = listMp4s(outputDir).filter((file) => !before.has(file));
      if (current.length === 0) return '';
      current.sort((a, b) => fs.statSync(b).mtimeMs - fs.statSync(a).mtimeMs);
      const latest = current[0];
      const partial = fs.existsSync(`${latest}.crdownload`);
      const stableSize = fs.statSync(latest).size;
      await sleep(1000);
      const stable = fs.existsSync(latest) && fs.statSync(latest).size === stableSize && !partial;
      return stable ? latest : '';
    }, 120000);

    if (downloaded !== finalPath) {
      fs.rmSync(finalPath, { force: true });
      fs.renameSync(downloaded, finalPath);
    }
    console.log(`Downloaded: ${finalPath}`);
  } finally {
    client.close();
  }
}

main().catch((error) => {
  console.error(error.stack || String(error));
  process.exit(1);
});
