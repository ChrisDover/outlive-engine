/**
 * Application-layer encryption for sensitive fields stored in Prisma
 * (OAuth tokens, etc.) using AES-256-GCM via Node.js crypto.
 *
 * Key derivation uses HKDF-SHA256, matching the backend's approach.
 */

import { createCipheriv, createDecipheriv, randomBytes, hkdfSync } from "crypto";

const ALGORITHM = "aes-256-gcm";
const IV_LENGTH = 12;
const TAG_LENGTH = 16;
const HKDF_SALT = "outlive-web-token-encryption-v1";
const HKDF_INFO = "token-encryption";

function getKey(): Buffer {
  const secret = process.env.NEXTAUTH_SECRET;
  if (!secret) throw new Error("NEXTAUTH_SECRET is required for token encryption");
  return Buffer.from(
    hkdfSync("sha256", secret, HKDF_SALT, HKDF_INFO, 32)
  );
}

/** Encrypt a plaintext string. Returns base64(iv + ciphertext + tag). */
export function encryptToken(plaintext: string): string {
  const key = getKey();
  const iv = randomBytes(IV_LENGTH);
  const cipher = createCipheriv(ALGORITHM, key, iv);
  const encrypted = Buffer.concat([cipher.update(plaintext, "utf8"), cipher.final()]);
  const tag = cipher.getAuthTag();
  return Buffer.concat([iv, encrypted, tag]).toString("base64");
}

/** Decrypt a base64(iv + ciphertext + tag) string back to plaintext. */
export function decryptToken(ciphertext: string): string {
  const key = getKey();
  const raw = Buffer.from(ciphertext, "base64");
  const iv = raw.subarray(0, IV_LENGTH);
  const tag = raw.subarray(raw.length - TAG_LENGTH);
  const encrypted = raw.subarray(IV_LENGTH, raw.length - TAG_LENGTH);
  const decipher = createDecipheriv(ALGORITHM, key, iv);
  decipher.setAuthTag(tag);
  return decipher.update(encrypted) + decipher.final("utf8");
}
