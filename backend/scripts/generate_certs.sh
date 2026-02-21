#!/usr/bin/env bash
# Generate self-signed TLS certificates for local development / mTLS.
set -euo pipefail

CERT_DIR="$(cd "$(dirname "$0")/.." && pwd)/certs"
mkdir -p "$CERT_DIR"

DAYS=365
SUBJ="/CN=outlive-engine-dev"

echo "Generating CA key + cert ..."
openssl req -x509 -newkey rsa:4096 -nodes \
    -keyout "$CERT_DIR/ca-key.pem" \
    -out    "$CERT_DIR/ca-cert.pem" \
    -days   "$DAYS" \
    -subj   "/CN=Outlive Engine Dev CA"

echo "Generating server key + CSR ..."
openssl req -newkey rsa:4096 -nodes \
    -keyout "$CERT_DIR/server-key.pem" \
    -out    "$CERT_DIR/server.csr" \
    -subj   "$SUBJ"

echo "Signing server certificate with CA ..."
openssl x509 -req \
    -in      "$CERT_DIR/server.csr" \
    -CA      "$CERT_DIR/ca-cert.pem" \
    -CAkey   "$CERT_DIR/ca-key.pem" \
    -CAcreateserial \
    -out     "$CERT_DIR/server-cert.pem" \
    -days    "$DAYS"

echo "Generating client key + CSR (for mTLS) ..."
openssl req -newkey rsa:4096 -nodes \
    -keyout "$CERT_DIR/client-key.pem" \
    -out    "$CERT_DIR/client.csr" \
    -subj   "/CN=outlive-client"

echo "Signing client certificate with CA ..."
openssl x509 -req \
    -in      "$CERT_DIR/client.csr" \
    -CA      "$CERT_DIR/ca-cert.pem" \
    -CAkey   "$CERT_DIR/ca-key.pem" \
    -CAcreateserial \
    -out     "$CERT_DIR/client-cert.pem" \
    -days    "$DAYS"

# Clean up CSR files
rm -f "$CERT_DIR"/*.csr "$CERT_DIR"/*.srl

echo ""
echo "Certificates written to: $CERT_DIR"
echo "  CA:     ca-cert.pem / ca-key.pem"
echo "  Server: server-cert.pem / server-key.pem"
echo "  Client: client-cert.pem / client-key.pem"
