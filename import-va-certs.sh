#!/usr/bin/env bash

set -euo pipefail

(
    cd /usr/local/share/ca-certificates/

    curl -LO https://cacerts.digicert.com/DigiCertTLSRSASHA2562020CA1-1.crt.pem
    curl -LO https://digicert.tbs-certificats.com/DigiCertGlobalG2TLSRSASHA2562020CA1.crt

    # DoD ECA with multiple fallback mechanisms
    (
        echo "Downloading DoD ECA certificates..."

        # Primary: HTTPS with timeout and retries
        if curl --fail --silent --show-error --connect-timeout 10 --max-time 60 --retry 3 --retry-delay 5 -o unclass-certificates_pkcs7_ECA.zip https://dl.dod.cyber.mil/wp-content/uploads/pki-pke/zip/unclass-certificates_pkcs7_ECA.zip; then
            echo "✓ DoD ECA downloaded via HTTPS"
        # Fallback 1: HTTP with timeout and retries
        elif curl --connect-timeout 10 --max-time 60 --retry 3 --retry-delay 5 -LO http://dl.dod.cyber.mil/wp-content/uploads/pki-pke/zip/unclass-certificates_pkcs7_ECA.zip; then
            echo "✓ DoD ECA downloaded via HTTP fallback"
        else
            echo "✗ All DoD ECA download attempts failed"
            echo "Continuing without DoD ECA certificates..."
            # Note: Removed exit 1 to allow script to continue
        fi

        # Process the downloaded certificates
        if [ -f "unclass-certificates_pkcs7_ECA.zip" ]; then
            unzip ./unclass-certificates_pkcs7_ECA.zip -d ECA_CA
            cd ECA_CA/certificates_pkcs7_v5_12_eca/
            openssl pkcs7 -inform DER -in ./certificates_pkcs7_v5_12_eca_ECA_Root_CA_5_der.p7b -print_certs | awk '/BEGIN/{i++} {print > ("eca_cert" i ".pem")}'
            rm -f eca_cert.pem # first one is always invalid because of how awk is breaking it up
            cp *.pem ../../
            echo "✓ DoD ECA certificates processed successfully"
        else
            echo "✗ DoD ECA zip file not found after download attempts"
        fi
    )

    echo "Downloading VA certificates..."
    wget \
        --level=1 \
        --quiet \
        --recursive \
        --no-parent \
        --no-host-directories \
        --no-directories \
        --accept="VA*.cer" \
        http://aia.pki.va.gov/PKI/AIA/VA/

    for cert in *.{cer,pem}
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
    | grep -iE '(VA-Internal|DigiCert)'
)
