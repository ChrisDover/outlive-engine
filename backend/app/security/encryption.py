"""AES-256-GCM field-level encryption for sensitive database columns."""

from __future__ import annotations

import base64
import os

from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from cryptography.hazmat.primitives.hashes import SHA256
from cryptography.hazmat.primitives.kdf.hkdf import HKDF

# Nonce length recommended by NIST for AES-GCM
_NONCE_BYTES = 12

# Static salt for deterministic key derivation (not a secret, just domain separation)
_HKDF_SALT = b"outlive-engine-field-encryption-v1"


def derive_key(secret: str) -> bytes:
    """Derive a 256-bit key from an arbitrary-length secret string.

    Uses HKDF-SHA256 with a static salt for proper cryptographic key
    derivation.  This is backwards-compatible: the same secret always
    produces the same derived key.
    """
    hkdf = HKDF(
        algorithm=SHA256(),
        length=32,
        salt=_HKDF_SALT,
        info=b"field-encryption",
    )
    return hkdf.derive(secret.encode("utf-8"))


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
