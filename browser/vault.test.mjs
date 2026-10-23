import {test} from 'node:test';
import assert from 'node:assert/strict';
import {derive,newSalt,seal,unseal,redact,maxBackupBytes,validateEnvelope} from './dist/vault.mjs';
test('encrypted vault roundtrip, fresh nonces, wrong password and tamper rejection',async () => {
 const salt = newSalt(), key = await derive('correct horse test phrase',salt);
 const data = {entries:[{id:'test',title:'Private',body:'Secret data'}]};
 const a = await seal(data,key,salt), b = await seal(data,key,salt);
 assert.notEqual(a.iv,b.iv); assert(!JSON.stringify(a).includes('Secret data'));
 assert.deepEqual(await unseal(a,key),data);
 await assert.rejects(unseal(a,await derive('wrong passphrase',salt)));
 const bad = {...a,ciphertext:(a.ciphertext[0] === 'A' ? 'B' : 'A') + a.ciphertext.slice(1)};
 await assert.rejects(unseal(bad,key));
 await assert.rejects(unseal({...a,iterations:1},key));
});
test('redacts supported structured identifiers while retaining ordinary text',() => {
 const result = redact('Write me at adam@example.com or (415) 555-1234. SSN 123-45-6789. IP 192.168.1.1. Card 4111 1111 1111 1111.');
 for (const raw of ['adam@example.com','555-1234','123-45-6789','192.168.1.1','4111']) assert(!result.includes(raw));
 assert.equal(redact('I prefer clear instructions.'),'I prefer clear instructions.');
});

test('near-limit backups unlock and restore; oversized and multibyte saves fail', async () => {
 const salt = newSalt(), key = await derive('test backup boundary password', salt);
 const make = (count, body) => ({entries:Array.from({length:count}, (_, i) => ({id:String(i),title:'Context',body}))});
 const near = make(149, 'x'.repeat(20000));
 const envelope = await seal(near,key,salt);
 const exported = JSON.stringify(envelope);
 assert(Buffer.byteLength(exported) <= maxBackupBytes);
 assert(Buffer.byteLength(exported) > maxBackupBytes - 30000);
 assert.deepEqual(await unseal(JSON.parse(exported),key),near);
 await assert.rejects(seal(make(150,'x'.repeat(20000)),key,salt), /4 MB/);
 await assert.rejects(seal(make(60,'界'.repeat(20000)),key,salt), /4 MB/);
 // Ciphertext alone can fit while the complete backup is too large.
 assert.throws(() => validateEnvelope({...envelope,ciphertext:'A'.repeat(maxBackupBytes)}), /4 MB/);
});
test('write validation rejects every schema shape the reader rejects',async () => {
 const salt = newSalt(), key = await derive('test invalid schema password',salt);
 for (const invalid of [null,{}, {entries:[null]}, {entries:Array(501).fill({id:'a',title:'b',body:'c'})}, {entries:[{id:'a',title:'x'.repeat(121),body:'c'}]}, {entries:[{id:'a',title:'b',body:'x'.repeat(20001)}]}]) {
  await assert.rejects(seal(invalid,key,salt), /Invalid vault data/);
 }
});
