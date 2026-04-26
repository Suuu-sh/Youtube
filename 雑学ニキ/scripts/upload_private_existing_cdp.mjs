#!/usr/bin/env node

import fs from 'fs';
import process from 'process';

const [, , portArg, videoPath, title, description, syntheticDisclosureArg] = process.argv;

if (!portArg || !videoPath || !title) {
  console.error('Usage: node upload_private_via_cdp.mjs <port> <videoPath> <title> [description]');
  process.exit(1);
}

const port = Number(portArg);
const desc = description ?? '';
const syntheticDisclosure = ['1', 'true', 'yes', 'y'].includes(String(syntheticDisclosureArg ?? '').toLowerCase());

if (!fs.existsSync(videoPath)) {
  console.error(`Video not found: ${videoPath}`);
  process.exit(1);
}

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

class CDPClient {
  constructor(wsUrl) {
    this.ws = new WebSocket(wsUrl);
    this.nextId = 1;
    this.pending = new Map();
    this.events = [];
  }

  async connect() {
    await new Promise((resolve, reject) => {
      this.ws.addEventListener('open', resolve, { once: true });
      this.ws.addEventListener('error', reject, { once: true });
    });

    this.ws.addEventListener('message', (event) => {
      const msg = JSON.parse(String(event.data));
      if (msg.id) {
        const pending = this.pending.get(msg.id);
        if (!pending) return;
        this.pending.delete(msg.id);
        if (msg.error) pending.reject(new Error(msg.error.message));
        else pending.resolve(msg.result);
        return;
      }
      this.events.push(msg);
    });
  }

  send(method, params = {}) {
    const id = this.nextId++;
    const payload = JSON.stringify({ id, method, params });
    return new Promise((resolve, reject) => {
      this.pending.set(id, { resolve, reject });
      this.ws.send(payload);
    });
  }

  close() {
    this.ws.close();
  }
}

async function httpJson(url, opts) {
  const res = await fetch(url, opts);
  if (!res.ok) {
    throw new Error(`HTTP ${res.status} for ${url}`);
  }
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

async function waitFor(client, label, fn, timeoutMs = 120000, intervalMs = 500) {
  const started = Date.now();
  while (Date.now() - started < timeoutMs) {
    const value = await fn();
    if (value) return value;
    await sleep(intervalMs);
  }
  throw new Error(`Timed out waiting for ${label}`);
}

function jsString(value) {
  return JSON.stringify(value);
}

async function clickByText(client, text) {
  return await evalValue(
    client,
    `(() => {
      const wanted = ${jsString(text)}.trim().toLowerCase();
      const candidates = [...document.querySelectorAll('button, tp-yt-paper-button, ytcp-button, [role="button"]')];
      for (const raw of candidates) {
        const el = raw.matches('button') ? raw : raw.querySelector('button') || raw;
        const label = (el.innerText || raw.innerText || '').trim().toLowerCase();
        const disabled = el.disabled || raw.disabled || raw.hasAttribute('disabled') || raw.getAttribute('aria-disabled') === 'true';
        if (label === wanted && !disabled) {
          (raw.click ? raw : el).click();
          return true;
        }
      }
      return false;
    })()`
  );
}

async function clickRadioLike(client, wantedText) {
  return await evalValue(
    client,
    `(() => {
      const wanted = ${jsString(wantedText)}.trim().toLowerCase();
      const candidates = [...document.querySelectorAll('tp-yt-paper-radio-button, [role="radio"], tp-yt-paper-checkbox, [role="checkbox"]')];
      for (const el of candidates) {
        const label = (el.innerText || '').trim().toLowerCase();
        if (label.includes(wanted)) {
          el.click();
          return true;
        }
      }
      return false;
    })()`
  );
}

async function dismissCommonModals(client) {
  const labels = ['Continue', 'Got it', 'Close'];
  for (const label of labels) {
    await clickByText(client, label).catch(() => {});
    await sleep(600);
  }
}

async function setEditor(client, selectors, text) {
  return await evalValue(
    client,
    `(() => {
      const selectors = ${jsString(selectors)};
      const text = ${jsString(text)};
      const fire = (el) => {
        el.dispatchEvent(new InputEvent('input', { bubbles: true, inputType: 'insertText', data: text }));
        el.dispatchEvent(new Event('change', { bubbles: true }));
      };
      for (const sel of selectors) {
        const el = document.querySelector(sel);
        if (!el) continue;
        const target = el.matches('input, textarea, [contenteditable="true"]') ? el : (el.querySelector('[contenteditable="true"], textarea, input') || el);
        if (!target) continue;
        target.focus();
        if (target.matches('input, textarea')) {
          target.value = text;
        } else {
          target.textContent = '';
          target.textContent = text;
        }
        fire(target);
        return sel;
      }
      return null;
    })()`
  );
}

async function setTextboxByAriaPrefix(client, ariaPrefix, text) {
  return await evalValue(
    client,
    `(() => {
      const wanted = ${jsString(ariaPrefix.toLowerCase())};
      const text = ${jsString(text)};
      const candidates = [
        ...document.querySelectorAll('[contenteditable="true"]'),
        ...document.querySelectorAll('[aria-label]'),
      ];
      const target = candidates.find((el) =>
        (el.getAttribute('aria-label') || '').toLowerCase().startsWith(wanted)
      );
      if (!target) return null;
      target.focus();
      target.textContent = text;
      target.innerText = text;
      target.dispatchEvent(
        new InputEvent('input', {
          bubbles: true,
          inputType: 'insertText',
          data: text,
        })
      );
      target.dispatchEvent(new Event('change', { bubbles: true }));
      target.blur();
      return {
        aria: target.getAttribute('aria-label') || '',
        text: target.innerText || target.textContent || '',
      };
    })()`
  );
}

async function setMetadata(client, title, desc) {
  console.log('Setting title/description...');
  const titleResult =
    (await setTextboxByAriaPrefix(
      client,
      'Add a title',
      title
    )) ||
    (await setEditor(
      client,
      [
        '#title-textarea #textbox',
        '#title-textarea textarea',
        '#title-textarea [contenteditable="true"]',
        '[aria-label^="Add a title"]',
        '[aria-label*="title"]',
      ],
      title
    ));

  if (!titleResult) {
    throw new Error('Could not find the YouTube title editor.');
  }

  if (desc.trim()) {
    const descResult =
      (await setTextboxByAriaPrefix(client, 'Tell viewers about your video', desc)) ||
      (await setEditor(
        client,
        [
          '#description-textarea #textbox',
          '#description-textarea textarea',
          '#description-textarea [contenteditable="true"]',
          '[aria-label^="Tell viewers about your video"]',
          '[aria-label*="description"]',
        ],
        desc
      ));
    if (!descResult) {
      throw new Error('Could not find the YouTube description editor.');
    }
  }
}

async function setAudienceNoKids(client) {
  console.log('Setting audience if required...');
  await clickRadioLike(client, "No, it's not made for kids").catch(() => {});
  await sleep(1000);
}

async function setSyntheticDisclosure(client) {
  console.log('Setting altered/synthetic content disclosure if available...');
  await evalValue(
    client,
    `(() => {
      const bodyText = document.body?.innerText || '';
      if (!/altered|synthetic|AI-generated|生成|合成|改変/i.test(bodyText)) return 'not-present';

      const controls = [...document.querySelectorAll('tp-yt-paper-radio-button, [role="radio"], tp-yt-paper-checkbox, [role="checkbox"]')];
      const positive = controls.find((el) => {
        const text = (el.innerText || '').trim().toLowerCase();
        return text === 'yes' || text.startsWith('yes') || text.includes('はい') || text.includes('yes,');
      });
      if (positive) {
        positive.click();
        return 'clicked-control';
      }

      const buttons = [...document.querySelectorAll('button, ytcp-button, tp-yt-paper-button, [role="button"]')];
      const yesButton = buttons.find((raw) => {
        const el = raw.matches('button') ? raw : raw.querySelector('button') || raw;
        const text = (el.innerText || raw.innerText || '').trim().toLowerCase();
        const disabled = el.disabled || raw.disabled || raw.hasAttribute('disabled') || raw.getAttribute('aria-disabled') === 'true';
        return !disabled && (text === 'yes' || text.includes('はい'));
      });
      if (yesButton) {
        yesButton.click();
        return 'clicked-button';
      }
      return 'not-found';
    })()`
  ).catch(() => {});
  await sleep(1000);
}

async function clickNextStep(client, count = 3) {
  for (let i = 0; i < count; i += 1) {
    const clicked = await evalValue(
      client,
      `(() => {
        const host = document.querySelector('#next-button');
        if (!host) return '';
        const btn = host.querySelector('button') || host;
        const disabled = btn.disabled || host.disabled || host.hasAttribute('disabled') || host.getAttribute('aria-disabled') === 'true';
        if (disabled) return 'disabled';
        host.click();
        return 'clicked';
      })()`
    );
    if (!clicked) {
      await clickByText(client, 'Next').catch(() => {});
    }
    await sleep(1500);
  }
}

async function setPrivateAndSave(client) {
  await waitFor(
    client,
    'visibility step',
    async () =>
      await evalValue(
        client,
        `(() => {
          const text = document.body?.innerText || '';
          return text.includes('Save or publish') || text.includes('Private');
        })()`
      ),
    120000
  );

  console.log('Ensuring private visibility...');
  const privateClicked =
    (await evalValue(
      client,
      `(() => {
        const radios = [...document.querySelectorAll('tp-yt-paper-radio-button, [role="radio"]')];
        for (const el of radios) {
          const text = (el.innerText || '').trim().toLowerCase();
          if (text === 'private' || text.includes('private')) {
            el.click();
            return true;
          }
        }
        return false;
      })()`
    )) || false;

  if (!privateClicked) {
    await clickByText(client, 'Private').catch(() => {});
  }

  await sleep(1500);

  console.log('Saving upload as private...');
  const saved =
    (await evalValue(
      client,
      `(() => {
        for (const selector of ['#done-button', '#save-button']) {
          const host = document.querySelector(selector);
          if (!host) continue;
          const btn = host.querySelector('button') || host;
          const disabled = btn.disabled || host.disabled || host.hasAttribute('disabled') || host.getAttribute('aria-disabled') === 'true';
          if (disabled) continue;
          host.click();
          return selector;
        }
        return '';
      })()`
    )) || '';

  if (!saved) {
    const clickedDone = await clickByText(client, 'Done');
    if (!clickedDone) {
      await clickByText(client, 'Save');
    }
  }

  await sleep(20000);
}

async function waitForDetailsDialog(client) {
  await waitFor(
    client,
    'upload details dialog',
    async () =>
      await evalValue(
        client,
        `(() => {
          const text = document.body?.innerText || '';
          const editors = [...document.querySelectorAll('[contenteditable="true"], textarea, input[type="text"]')];
          return editors.length > 0 && (text.includes('Details') || text.includes('Title (required)'));
        })()`
      ),
    180000
  );
}

async function completeCurrentDialog(client, title, desc) {
  await waitForDetailsDialog(client);
  await setMetadata(client, title, desc);
  if (syntheticDisclosure) {
    // The altered/synthetic content controls can be hidden under advanced settings.
    await clickByText(client, 'Show more').catch(() => {});
    await sleep(1000);
    await setSyntheticDisclosure(client);
  }
  await setAudienceNoKids(client);
  await clickNextStep(client, 3);
  await setPrivateAndSave(client);
}

async function openShortsList(client) {
  await client.send('Page.navigate', {
    url: 'https://studio.youtube.com/channel/UCwA8z3WDB34cbbLKlicktxg/videos/short',
  });
  await waitFor(
    client,
    'shorts list',
    async () =>
      await evalValue(
        client,
        `(() => {
          const text = document.body?.innerText || '';
          return text.includes('Channel content') && text.includes('Shorts');
        })()`
      ),
    120000
  );
  await dismissCommonModals(client);
  await sleep(2000);
}

async function readShortsState(client, wantedTitle) {
  return await evalValue(
    client,
    `(() => {
      const wanted = ${jsString(wantedTitle.toLowerCase())};
      const rows = [...document.querySelectorAll('ytcp-video-row, ytcp-content-row, [id="row-container"]')]
        .map((row) => (row.innerText || '').trim())
        .filter(Boolean);
      const body = document.body?.innerText || '';
      const wantedPrivateRow = rows.find((row) => {
        const lower = row.toLowerCase();
        return lower.includes(wanted) && lower.includes('private');
      }) || '';
      return {
        body,
        rows,
        hasPrivate: body.toLowerCase().includes('private'),
        hasDraft: body.toLowerCase().includes('draft'),
        hasWantedTitle: body.toLowerCase().includes(wanted),
        hasWantedPrivateRow: Boolean(wantedPrivateRow),
        wantedPrivateRow,
      };
    })()`
  );
}

async function openLatestDraft(client) {
  const clicked = await evalValue(
    client,
    `(() => {
      const buttons = [...document.querySelectorAll('button, tp-yt-paper-button, ytcp-button, [role="button"]')];
      for (const raw of buttons) {
        const el = raw.matches('button') ? raw : raw.querySelector('button') || raw;
        const text = (el.innerText || raw.innerText || '').trim().toLowerCase();
        const disabled = el.disabled || raw.disabled || raw.hasAttribute('disabled') || raw.getAttribute('aria-disabled') === 'true';
        if (!disabled && (text === 'edit draft' || text === 'resume upload')) {
          (raw.click ? raw : el).click();
          return text;
        }
      }
      return '';
    })()`
  );
  if (!clicked) return false;
  await waitForDetailsDialog(client);
  return true;
}

async function ensurePrivateUpload(client, title, desc) {
  await openShortsList(client);
  let state = await readShortsState(client, title);
  const started = Date.now();
  while (!(state.hasWantedPrivateRow || (state.hasWantedTitle && state.hasPrivate && !state.hasDraft)) && Date.now() - started < 180000) {
    await sleep(5000);
    await client.send('Page.navigate', {
      url: 'https://studio.youtube.com/channel/UCwA8z3WDB34cbbLKlicktxg/videos/short',
    });
    await sleep(4000);
    state = await readShortsState(client, title);
  }
  if (state.hasWantedPrivateRow || (state.hasWantedTitle && state.hasPrivate && !state.hasDraft)) {
    console.log('Verified uploaded Short is private.');
    return state;
  }

  console.log('Short requires draft completion; reopening latest draft...');
  const openedDraft = await openLatestDraft(client);
  if (!openedDraft) {
    throw new Error('Could not find the uploaded Short in YouTube Studio.');
  }

  await completeCurrentDialog(client, title, desc);
  await openShortsList(client);
  state = await readShortsState(client, title);
  if (!(state.hasWantedPrivateRow || (state.hasWantedTitle && state.hasPrivate && !state.hasDraft))) {
    throw new Error('The Short upload did not finish as private.');
  }

  console.log('Verified uploaded Short is private after draft completion.');
  return state;
}

async function main() {
  const pages = await httpJson(`http://127.0.0.1:${port}/json/list`);
  const target = pages.find((p) => p.type === 'page' && p.url.includes('studio.youtube.com/channel/UCwA8z3WDB34cbbLKlicktxg'))
    || await createTarget(port, 'about:blank');
  const client = new CDPClient(target.webSocketDebuggerUrl);
  await client.connect();

  try {
    await client.send('Page.enable');
    await client.send('Runtime.enable');
    await client.send('DOM.enable');

    await client.send('Page.navigate', {
      url: 'https://studio.youtube.com/channel/UCwA8z3WDB34cbbLKlicktxg/videos/upload?d=ud',
    });

    await waitFor(
      client,
      'upload page or login page',
      async () =>
        await evalValue(
          client,
          `(() => {
            if (location.host.includes('accounts.google.com')) return 'login';
            if (document.querySelector('input[type="file"]')) return 'upload';
            return '';
          })()`
        ),
      60000
    ).then((state) => {
      if (state === 'login') {
        throw new Error('The temporary Chrome profile was not logged in to YouTube/Google.');
      }
    });

    const { root } = await client.send('DOM.getDocument', { depth: -1, pierce: true });
    const { nodeId } = await client.send('DOM.querySelector', {
      nodeId: root.nodeId,
      selector: 'input[type="file"]',
    });
    if (!nodeId) {
      throw new Error('Could not find YouTube upload file input.');
    }

    console.log('Selecting video file...');
    await client.send('DOM.setFileInputFiles', {
      nodeId,
      files: [videoPath],
    });

    await completeCurrentDialog(client, title, desc);
    await ensurePrivateUpload(client, title, desc);

    console.log('Private upload flow completed.');
  } finally {
    client.close();
  }
}

main().catch((error) => {
  console.error(error.stack || String(error));
  process.exit(1);
});
