const enc = new TextEncoder();
const dec = new TextDecoder();
export const iterations = 600000;
export const maxBackupBytes = 4000000;
function validateData(data) {
  if (!data || !Array.isArray(data.entries) || data.entries.length > 500 || data.entries.some(x => !x || typeof x.id !== 'string' || typeof x.title !== 'string' || typeof x.body !== 'string' || x.title.length > 120 || x.body.length > 20000)) throw Error('Invalid vault data.');
}
const b64 = bytes => btoa(Array.from(bytes, n => String.fromCharCode(n)).join(''));
const bytes = value => Uint8Array.from(atob(value), c => c.charCodeAt(0));
export async function derive(password, salt) {
  const material = await crypto.subtle.importKey('raw', enc.encode(password), 'PBKDF2', false, ['deriveKey']);
  return crypto.subtle.deriveKey({name:'PBKDF2', hash:'SHA-256', salt:bytes(salt), iterations}, material, {name:'AES-GCM', length:256}, false, ['encrypt','decrypt']);
}
export function newSalt() { return b64(crypto.getRandomValues(new Uint8Array(16))); }
export async function seal(data, key, salt) {
  validateData(data);
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const ciphertext = await crypto.subtle.encrypt({name:'AES-GCM', iv}, key, enc.encode(JSON.stringify(data)));
  const envelope = {format:'trulana-browser', version:1, iterations, salt, iv:b64(iv), ciphertext:b64(new Uint8Array(ciphertext))};
  validateEnvelope(envelope);
  return envelope;
}
export function validateEnvelope(e) {
  if (enc.encode(JSON.stringify(e)).byteLength > maxBackupBytes) throw Error('Vault exceeds the 4 MB backup limit. Your saved vault was not changed. Reduce the new entry or remove unneeded context after backing up.');
  if (!e || e.format !== 'trulana-browser' || e.version !== 1 || e.iterations !== iterations || typeof e.ciphertext !== 'string' || e.ciphertext.length > maxBackupBytes || bytes(e.salt).length !== 16 || bytes(e.iv).length !== 12) throw Error('Invalid backup format.');
}
export async function unseal(e, key) {
  validateEnvelope(e);
  const plaintext = await crypto.subtle.decrypt({name:'AES-GCM', iv:bytes(e.iv)}, key, bytes(e.ciphertext));
  const data = JSON.parse(dec.decode(plaintext));
  validateData(data);
  return data;
}
export function redact(text) {
  return text.replace(/\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/gi, '[EMAIL]')
    .replace(/\b\d{3}-\d{2}-\d{4}\b/g, '[SSN]')
    .replace(/\b(?:\d{1,3}\.){3}\d{1,3}\b/g, '[IP ADDRESS]')
    .replace(/\b(?:\d[ -]?){13,19}\b/g, '[LONG NUMBER]')
    .replace(/(?:\+?1[ .-]?)?\(?\b\d{3}\)?[ .-]\d{3}[ .-]\d{4}\b/g, '[PHONE]');
}
