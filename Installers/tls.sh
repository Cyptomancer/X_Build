#!/usr/bin/env bash

set -euo pipefail

# ============================================================
# Interactive TLS Certificate Generator
# Requires: openssl
# ============================================================

if ! command -v openssl >/dev/null 2>&1; then
    echo "[!] OpenSSL is not installed."
    echo "    Debian/Ubuntu: sudo apt install openssl"
    exit 1
fi

echo
echo "=============================================="
echo "       Interactive TLS Certificate Maker"
echo "=============================================="
echo

read -rp "Common Name (CN) [localhost]: " CN
CN="${CN:-localhost}"

read -rp "Subject Alternative Names [${CN}]: " SAN_INPUT
SAN_INPUT="${SAN_INPUT:-$CN}"

read -rp "Certificate validity in days [365]: " DAYS
DAYS="${DAYS:-365}"

read -rp "Output directory [./tls]: " OUTDIR
OUTDIR="${OUTDIR:-./tls}"

read -rp "Certificate filename [server.crt]: " CERT_NAME
CERT_NAME="${CERT_NAME:-server.crt}"

read -rp "Private key filename [server.key]: " KEY_NAME
KEY_NAME="${KEY_NAME:-server.key}"

echo
echo "----------------------------------------------"
echo "Configuration"
echo "----------------------------------------------"
echo "CN:          $CN"
echo "SANs:        $SAN_INPUT"
echo "Valid days:  $DAYS"
echo "Output dir:  $OUTDIR"
echo "Certificate: $CERT_NAME"
echo "Private key: $KEY_NAME"
echo "----------------------------------------------"
echo

read -rp "Continue? [Y/n]: " CONFIRM
CONFIRM="${CONFIRM:-Y}"

if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "[*] Cancelled."
    exit 0
fi

mkdir -p "$OUTDIR"

CERT_PATH="$OUTDIR/$CERT_NAME"
KEY_PATH="$OUTDIR/$KEY_NAME"

# Build SAN extension.
IFS=',' read -ra SAN_ARRAY <<< "$SAN_INPUT"

SAN_CONFIG="subjectAltName="

for i in "${!SAN_ARRAY[@]}"; do
    SAN="${SAN_ARRAY[$i]}"
    SAN="$(echo "$SAN" | xargs)"

    if [[ "$SAN" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        TYPE="IP"
    else
        TYPE="DNS"
    fi

    if [[ "$i" -gt 0 ]]; then
        SAN_CONFIG+=","
    fi

    SAN_CONFIG+="${TYPE}:${SAN}"
done

echo
echo "[*] Generating RSA private key..."

openssl genrsa \
    -out "$KEY_PATH" \
    4096

chmod 600 "$KEY_PATH"

echo "[+] Private key created:"
echo "    $KEY_PATH"

echo
echo "[*] Generating self-signed certificate..."

openssl req \
    -new \
    -x509 \
    -sha256 \
    -days "$DAYS" \
    -key "$KEY_PATH" \
    -out "$CERT_PATH" \
    -subj "/CN=$CN" \
    -addext "$SAN_CONFIG"

echo
echo "[+] Certificate created:"
echo "    $CERT_PATH"

echo
echo "=============================================="
echo "Certificate information"
echo "=============================================="

openssl x509 \
    -in "$CERT_PATH" \
    -noout \
    -subject \
    -issuer \
    -dates \
    -fingerprint \
    -ext subjectAltName

echo
echo "=============================================="
echo "Files"
echo "=============================================="
ls -lh "$CERT_PATH" "$KEY_PATH"

echo
echo "[+] TLS certificate generation complete."
echo
echo "Certificate:"
echo "  $CERT_PATH"
echo
echo "Private key:"
echo "  $KEY_PATH"
echo