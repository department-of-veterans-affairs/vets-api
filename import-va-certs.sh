#! /usr/bin/env bash

set -euo pipefail

(
    cd /usr/local/share/ca-certificates/

    curl -LO https://cacerts.digicert.com/DigiCertTLSRSASHA2562020CA1-1.crt.pem
    curl -LO https://digicert.tbs-certificats.com/DigiCertGlobalG2TLSRSASHA2562020CA1.crt

    # DoD ECA with multiple fallback mechanisms
    (
        echo "Downloading DoD ECA certificates..."
        
        # Primary: HTTPS with timeout and retries
        if curl --connect-timeout 10 --max-time 60 --retry 3 --retry-delay 5 -LO https://dl.dod.cyber.mil/wp-content/uploads/pki-pke/zip/unclass-certificates_pkcs7_ECA.zip; then
            echo "✓ DoD ECA downloaded via HTTPS"
        # Fallback 1: HTTP with timeout and retries
        elif curl --connect-timeout 10 --max-time 60 --retry 3 --retry-delay 5 -LO http://dl.dod.cyber.mil/wp-content/uploads/pki-pke/zip/unclass-certificates_pkcs7_ECA.zip; then
            echo "✓ DoD ECA downloaded via HTTP fallback"
        # Fallback 2: Alternative DoD mirror (if available)
        elif curl --connect-timeout 10 --max-time 60 --retry 3 --retry-delay 5 -LO https://crl.disa.mil/crl/DODECARCA5.zip; then
            echo "✓ DoD ECA downloaded from alternative mirror"
            mv DODECARCA5.zip unclass-certificates_pkcs7_ECA.zip
        else
            echo "✗ All DoD ECA download attempts failed"
            echo "Continuing without DoD ECA certificates..."
            return 0
        fi
        
        # Process the downloaded certificates
        if [ -f "unclass-certificates_pkcs7_ECA.zip" ]; then
            unzip ./unclass-certificates_pkcs7_ECA.zip -d ECA_CA
            cd ECA_CA/certificates_pkcs7_v5_12_eca/
            openssl pkcs7 -inform DER -in ./certificates_pkcs7_v5_12_eca_ECA_Root_CA_5_der.p7b -print_certs | awk '/BEGIN/{i++} {print > ("eca_cert" i ".pem")}'
            rm eca_cert.pem # first one is always invalid because of how awk is breaking it up
            cp *.pem ../../
            echo "✓ DoD ECA certificates processed successfully"
        else
            echo "✗ DoD ECA zip file not found after download attempts"
        fi
    )

    # VA certificates with enhanced fallback
    echo "Downloading VA certificates..."
    
    if wget \
        --level=1 \
        --timeout=30 \
        --tries=3 \
        --recursive \
        --no-parent \
        --no-host-directories \
        --no-directories \
        --accept="VA*.cer" \
        https://aia.pki.va.gov/PKI/AIA/VA/; then
        echo "✓ VA certificates downloaded via HTTPS"
    elif wget \
        --level=1 \
        --timeout=30 \
        --tries=3 \
        --recursive \
        --no-parent \
        --no-host-directories \
        --no-directories \
        --accept="VA*.cer" \
        http://aia.pki.va.gov/PKI/AIA/VA/; then
        echo "✓ VA certificates downloaded via HTTP fallback"
    else
        echo "✗ VA certificate download failed via both HTTPS and HTTP"
        echo "Continuing without VA certificates..."
    fi

    # Process and convert certificates
    echo "Processing downloaded certificates..."
    cert_count=0
    
    for cert in *.{cer,pem}
    do
        if [ -f "$cert" ] && [ "$cert" != "*.cer" ] && [ "$cert" != "*.pem" ]; then
            cert_count=$((cert_count + 1))
            echo "Processing certificate: $cert"
            
            if file "${cert}" | grep 'PEM'
            then
                cp "${cert}" "${cert}.crt"
                echo "  ✓ Copied PEM certificate to ${cert}.crt"
            else
                openssl x509 -in "${cert}" -inform der -outform pem -out "${cert}.crt"
                echo "  ✓ Converted DER certificate to ${cert}.crt"
            fi
            rm "${cert}"
        fi
    done
    
    echo "✓ Processed $cert_count certificates"

    echo "Updating system CA certificate store..."
    update-ca-certificates --fresh
    echo "✓ System CA certificate store updated"

    # Display VA Internal certificates that are now trusted
    echo "Verifying installed certificates..."
    trusted_certs=$(awk -v cmd='openssl x509 -noout -subject' '/BEGIN/{close(cmd)};{print | cmd}' < /etc/ssl/certs/ca-certificates.crt \
    | grep -iE '(VA-Internal|DigiCert)' | wc -l)
    
    if [ "$trusted_certs" -gt 0 ]; then
        echo "✓ Found $trusted_certs VA-Internal and DigiCert certificates in trust store"
        echo "Installed certificates:"
        awk -v cmd='openssl x509 -noout -subject' '/BEGIN/{close(cmd)};{print | cmd}' < /etc/ssl/certs/ca-certificates.crt \
        | grep -iE '(VA-Internal|DigiCert)' | sed 's/^/  /'
    else
        echo "⚠ No VA-Internal or DigiCert certificates found in trust store"
    fi
)
