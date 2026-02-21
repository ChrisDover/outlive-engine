"""AES-256-GCM field-level encryption for sensitive database columns."""

from __future__ import annotations

import base64
import hashlib
import os

from cryptography.hazmat.primitives.ciphers.aead import AESGCM

# Nonce length recommended by NIST for AES-GCM
_NONCE_BYTES = 12


def derive_key(secret: str) -> bytes:
    """Derive a 256-bit key from an arbitrary-length secret string.

    Uses SHA-256 for deterministic, fast key derivation.  For higher
    security requirements swap to HKDF or Argon2id.
    """
    return hashlib.sha256(secret.encode("utf-8")).digest()


def encrypt_field(plaintext: str, key: bytes) -> str:
    """Encrypt *plaintext* with AES-256-GCM and return a base64 string.

    Storage format (base64-encoded):  ``nonce || ciphertext || tag``
    """
    if not plaintext:
        return ""

    aesgcm = AESGCM(key)
    nonce = os.urandom(_NONCE_BYTES)
    ciphertext = aesgcm.encrypt(nonce, plaintext.encode("utf-8"), None)
    # ciphertext already includes the 16-byte GCM tag appended by cryptography
    return base64.b64encode(nonce + ciphertext).decode("ascii")


def decrypt_field(ciphertext: str, key: bytes) -> str:
    """Decrypt a base64-encoded AES-256-GCM blob back to plaintext."""
    if not ciphertext:
        return ""

    raw = base64.b64decode(ciphertext)
    nonce = raw[:_NONCE_BYTES]
    ct_with_tag = raw[_NONCE_BYTES:]

    aesgcm = AESGCM(key)
    plaintext_bytes = aesgcm.decrypt(nonce, ct_with_tag, None)
    return plaintext_bytes.decode("utf-8")
