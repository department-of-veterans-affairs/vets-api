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
        if curl --show-error --connect-timeout 10 --max-time 60 --retry 3 --retry-delay 5 -o unclass-certificates_pkcs7_ECA.zip https://dl.dod.cyber.mil/wp-content/uploads/pki-pke/zip/unclass-certificates_pkcs7_ECA.zip; then
            echo "✓ DoD ECA downloaded via HTTPS"
        # Fallback 1: HTTP with timeout and retries
        ## Uncomment in case the https call fails again
        ## Last time we got this error: Failed to connect to dl.dod.cyber.mil port 443
        elif curl --connect-timeout 10 --max-time 60 --retry 3 --retry-delay 5 -LO http://dl.dod.cyber.mil/wp-content/uploads/pki-pke/zip/unclass-certificates_pkcs7_ECA.zip; then
            echo "✓ DoD ECA downloaded via HTTP fallback"
        else
            echo "✗ All DoD ECA download attempts failed"
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

    # Check if any certificate files exist before processing
    shopt -s nullglob
    cert_files=(*.cer *.pem)
    shopt -u nullglob
    
    if [ ${#cert_files[@]} -eq 0 ]; then
        echo "Warning: No certificate files found to process"
    else
        echo "Processing ${#cert_files[@]} certificate files..."
    fi

    for cert in *.{cer,pem}
    do
        # Process certificate file
        [ ! -f "$cert" ] && continue
        
        if file "${cert}" | grep -q 'PEM'
        then
            cp "${cert}" "${cert}.crt"
        elif file "${cert}" | grep -q 'ASCII text'
        then
            # Handle base64-encoded DER (like VA-Internal-S2-ICA22.cer)
            if base64 -d "${cert}" > "${cert}.der" && [ -s "${cert}.der" ]
            then
                if openssl x509 -in "${cert}.der" -inform der -outform pem -out "${cert}.crt"
                then
                    rm "${cert}.der"
                else
                    echo "Error: Failed to convert ${cert} from DER to PEM format"
                    rm -f "${cert}.der" "${cert}.crt"
                    exit 1
                fi
            else
                echo "Error: Failed to decode base64 data in ${cert}"
                rm -f "${cert}.der"
                exit 1
            fi
        else
            # Binary DER format
            openssl x509 -in "${cert}" -inform der -outform pem -out "${cert}.crt"
        fi
        rm "${cert}"
    done

    update-ca-certificates --fresh

    # Display VA Internal certificates that are now trusted
    awk -v cmd='openssl x509 -noout -subject' '/BEGIN/{close(cmd)};{print | cmd}' < /etc/ssl/certs/ca-certificates.crt \
    | grep -iE '(VA-Internal|DigiCert)'
)