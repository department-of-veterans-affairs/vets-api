#! /usr/bin/env bash

set -euo pipefail

(
    cd /usr/local/share/ca-certificates/
    
    wget \
        --level=1 \
        --quiet \
        --recursive \
        --no-parent \
        --no-host-directories \
        --no-directories \
        --accept="VA*.cer" \
        http://aia.pki.va.gov/PKI/AIA/VA/

    for cert in VA-*.cer
    do
        if file "${cert}" | grep 'PEM'
        then
            cp "${cert}" "${cert}.crt"
        else
            openssl x509 -in "${cert}" -inform der -outform pem -out "${cert}.crt"
        fi
        rm "${cert}"
    done

    update-ca-certificates --fresh

    # Display VA Internal certificates that are now trusted
    awk -v cmd='openssl x509 -noout -subject' '/BEGIN/{close(cmd)};{print | cmd}' < /etc/ssl/certs/ca-certificates.crt \
    | grep -i 'VA-Internal'
)
