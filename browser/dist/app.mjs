import {derive, newSalt, seal, unseal, validateEnvelope, redact, maxBackupBytes} from './vault.mjs';
const $ = id => document.getElementById(id);
const storageKey = 'trulana-vault-v1';
let key = null, salt = null, data = null, releaseLock = null, timer, busy = false;
const message = text => { $('message').textContent = text; };
const stored = () => { const value = localStorage.getItem(storageKey); return value ? JSON.parse(value) : null; };
function gate() {
  const exists = !!localStorage.getItem(storageKey);
  $('gate-title').textContent = exists ? 'Welcome back. Unlock your vault.' : 'Create your private vault';
  $('unlock').textContent = exists ? 'Unlock vault ↗' : 'Create vault ↗';
  $('password').autocomplete = exists ? 'current-password' : 'new-password';
  $('gate').hidden = false; $('workspace').hidden = true;
}
function lock() {
  if (busy) { timer = setTimeout(lock, 1000); return; }
  clearTimeout(timer); key = salt = data = null;
  $('password').value = $('output').value = $('title').value = $('body').value = $('search').value = '';
  $('entries').replaceChildren(); $('preview').hidden = true;
  if (releaseLock) { releaseLock(); releaseLock = null; }
  gate(); message('Vault locked.');
}
function touch() { if (key) { clearTimeout(timer); timer = setTimeout(lock, 300000); } }
async function exclusive() {
  if (releaseLock) return;
  if (!navigator.locks) throw Error('This browser cannot safely coordinate vault tabs. Use a current Safari, Chrome, Edge, or Firefox.');
  await new Promise((resolve, reject) => {
    navigator.locks.request('trulana-vault-edit', {ifAvailable:true}, async granted => {
      if (!granted) { reject(Error('This vault is open in another tab. Lock that tab first.')); return; }
      await new Promise(release => { releaseLock = release; resolve(); });
    }).catch(reject);
  });
}
async function run(action) {
  if (busy) return;
  busy = true; document.querySelectorAll('button').forEach(b => b.disabled = true);
  try { await action(); touch(); } catch(e) { message(e.name === 'OperationError' ? 'Wrong passphrase or damaged backup. Your saved vault was not changed.' : (e.name === 'QuotaExceededError' ? 'Browser storage is full. Your changes were not saved. Export a backup.' : e.message)); }
  finally { busy = false; document.querySelectorAll('button').forEach(b => b.disabled = false); if (!key && releaseLock) { releaseLock(); releaseLock = null; } }
}
async function persist(next) {
  const encrypted = await seal(next, key, salt);
  localStorage.setItem(storageKey, JSON.stringify(encrypted));
  data = next;
}
function render() {
  const query = $('search').value.toLowerCase();
  $('count').textContent = `${data.entries.length} entries`;
  $('entries').replaceChildren();
  const matches = data.entries.filter(e => `${e.title} ${e.body}`.toLowerCase().includes(query));
  if (!matches.length) { const p = document.createElement('p'); p.className = 'small'; p.textContent = query ? 'No matching context.' : 'Your vault is empty. Add your first piece of context.'; $('entries').append(p); }
  for (const e of matches) {
    const card = document.createElement('article'); card.className = 'entry';
    const title = document.createElement('h3'); title.textContent = e.title;
    const body = document.createElement('p'); body.textContent = e.body.slice(0,180) + (e.body.length > 180 ? '…' : '');
    const preview = document.createElement('button'); preview.className = 'secondary'; preview.textContent = 'Review & redact ↗';
    preview.onclick = () => { $('output').value = redact(`${e.title}\n\n${e.body}`); $('preview').hidden = false; $('preview').scrollIntoView({behavior:'smooth'}); touch(); };
    const remove = document.createElement('button'); remove.className = 'secondary'; remove.textContent = 'Delete';
    remove.onclick = () => { if (confirm('Delete this entry? This cannot be undone.')) run(async () => { await persist({entries:data.entries.filter(x => x.id !== e.id)}); $('output').value = ''; $('preview').hidden = true; render(); message('Entry deleted.'); }); };
    card.append(title,body,preview,remove); $('entries').append(card);
  }
}
$('unlock-form').onsubmit = event => {
  event.preventDefault(); run(async () => {
    if (!crypto.subtle) throw Error('Encryption requires HTTPS and a browser with Web Crypto.');
    await exclusive();
    const envelope = stored(); if (envelope) validateEnvelope(envelope);
    const nextSalt = envelope ? envelope.salt : newSalt();
    const nextKey = await derive($('password').value, nextSalt);
    const nextData = envelope ? await unseal(envelope,nextKey) : {entries:[]};
    if (!envelope) localStorage.setItem(storageKey, JSON.stringify(await seal(nextData,nextKey,nextSalt)));
    key = nextKey; salt = nextSalt; data = nextData;
    $('password').value = ''; $('gate').hidden = true; $('workspace').hidden = false;
    render(); message(envelope ? 'Vault unlocked on this device.' : 'Vault created. Export a backup after adding your context.');
  });
};
$('entry-form').onsubmit = event => {
  event.preventDefault(); run(async () => {
    if (!key) throw Error('Unlock the vault first.');
    if (data.entries.length >= 500) throw Error('This early version supports up to 500 entries.');
    const title = $('title').value.trim(), body = $('body').value.trim();
    if (!title || !body) throw Error('Add a title and context.');
    await persist({entries:[{id:crypto.randomUUID(),title,body},...data.entries]});
    $('entry-form').reset(); render(); message('Context encrypted and saved on this device.');
  });
};
$('backup').onclick = () => run(async () => {
  const value = localStorage.getItem(storageKey); if (!value) throw Error('No saved vault to export.');
  const url = URL.createObjectURL(new Blob([value],{type:'application/json'}));
  const a = document.createElement('a'); a.href = url; a.download = `trulana-backup-${new Date().toISOString().slice(0,10)}.json`; a.click(); setTimeout(() => URL.revokeObjectURL(url),10000);
  message('Encrypted backup prepared. Keep it with your passphrase stored separately.');
});
$('restore-file').onchange = event => {
  const file = event.target.files[0]; event.target.value = ''; if (!file) return;
  run(async () => {
    if (!$('password').value) throw Error('Enter the backup passphrase before selecting a backup.');
    if (file.size > maxBackupBytes) throw Error('Backup exceeds the 4 MB import limit.');
    await exclusive();
    const envelope = JSON.parse(await file.text()); validateEnvelope(envelope);
    const restoreKey = await derive($('password').value,envelope.salt);
    await unseal(envelope,restoreKey);
    if (localStorage.getItem(storageKey) && !confirm('Replace this browser’s vault with this backup? Export the existing vault first if you need it.')) return;
    localStorage.setItem(storageKey,JSON.stringify(envelope)); $('password').value = ''; gate(); message('Backup restored. Enter its passphrase to unlock.');
  });
};
$('copy').onclick = () => run(async () => { await navigator.clipboard.writeText($('output').value); message('Reviewed text copied. The clipboard now contains this text.'); });
$('close-preview').onclick = () => { $('preview').hidden = true; $('output').value = ''; };
$('search').oninput = render;
$('lock').onclick = lock;
$('delete-vault').onclick = () => { if (confirm('Permanently delete this browser’s vault? Only an exported backup can restore it.')) { localStorage.removeItem(storageKey); lock(); message('Local vault deleted. Downloaded backups still exist.'); } };
for (const event of ['pointerdown','keydown']) document.addEventListener(event,touch);
window.addEventListener('pagehide',lock);
try { gate(); } catch { message('Browser storage is unavailable. Enable site storage to use this vault.'); $('unlock').disabled = true; }
