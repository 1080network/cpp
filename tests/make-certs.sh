#!/bin/bash
# Generates throwaway certificates for the mutual TLS test: a CA, a server and a client certificate signed by it (for
# localhost and 127.0.0.1), and an unrelated second CA.
set -euo pipefail
DIR=${1:?usage: make-certs.sh <output dir>}
mkdir -p "$DIR" && cd "$DIR"

ca() { # <name>
    openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -nodes -days 1 \
        -subj "/CN=$1" -keyout "$1.key" -out "$1.crt" 2>/dev/null
}
leaf() { # <name>
    openssl req -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -nodes -subj "/CN=$1" -keyout "$1.key" -out "$1.csr" 2>/dev/null
    printf 'subjectAltName=DNS:localhost,IP:127.0.0.1\nbasicConstraints=CA:FALSE\n' > "$1.ext"
    openssl x509 -req -in "$1.csr" -CA ca.crt -CAkey ca.key -CAcreateserial -days 1 -extfile "$1.ext" -out "$1.crt" 2>/dev/null
}
ca ca
ca other-ca
leaf server
leaf client
echo "certificates written to $DIR"
