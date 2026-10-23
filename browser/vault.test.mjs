import {test} from 'node:test';
import assert from 'node:assert/strict';
import {derive,newSalt,seal,unseal,redact} from './dist/vault.mjs';
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
