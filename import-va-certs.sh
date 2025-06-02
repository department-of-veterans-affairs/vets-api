#! /usr/bin/env bash

set -euo pipefail

(
    cd /usr/local/share/ca-certificates/

    curl -LO https://cacerts.digicert.com/DigiCertTLSRSASHA2562020CA1-1.crt.pem
    curl -LO https://digicert.tbs-certificats.com/DigiCertGlobalG2TLSRSASHA2562020CA1.crt

    # DoD ECA
    (
        curl -LO https://dl.dod.cyber.mil/wp-content/uploads/pki-pke/zip/unclass-certificates_pkcs7_ECA.zip
        unzip ./unclass-certificates_pkcs7_ECA.zip
        cd certificates_pkcs7_v5_12_eca
        openssl pkcs7 -inform DER -in ./certificates_pkcs7_v5_12_eca_ECA_Root_CA_5_der.p7b -print_certs | awk '/BEGIN/{i++} {print > ("eca_cert" i ".pem")}'
        cp *.pem ../
    )

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
