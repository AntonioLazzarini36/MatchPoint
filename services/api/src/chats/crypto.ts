import * as crypto from 'crypto';

const ALGO = 'aes-256-gcm';
const VERSION = 'v1';

function getKey(): Buffer {
  const b64 = process.env.MESSAGE_KEY_BASE64;
  if (!b64) throw new Error('Missing env MESSAGE_KEY_BASE64');

  const key = Buffer.from(b64, 'base64');
  if (key.length !== 32)
    throw new Error('MESSAGE_KEY_BASE64 must decode to 32 bytes');
  return key;
}

export function encryptText(plain: string): string {
  const key = getKey();
  const iv = crypto.randomBytes(12); // recomendado para GCM
  const cipher = crypto.createCipheriv(ALGO, key, iv);

  const ct = Buffer.concat([cipher.update(plain, 'utf8'), cipher.final()]);
  const tag = cipher.getAuthTag();

  return `${VERSION}:${iv.toString('base64')}:${tag.toString('base64')}:${ct.toString('base64')}`;
}

export function decryptText(payload: string): string {
  const parts = payload.split(':');
  if (parts.length !== 4 || parts[0] !== VERSION) {
    throw new Error('Invalid ciphertext format');
  }

  const key = getKey();
  const iv = Buffer.from(parts[1], 'base64');
  const tag = Buffer.from(parts[2], 'base64');
  const ct = Buffer.from(parts[3], 'base64');

  const decipher = crypto.createDecipheriv(ALGO, key, iv);
  decipher.setAuthTag(tag);

  const plain = Buffer.concat([decipher.update(ct), decipher.final()]);
  return plain.toString('utf8');
}
