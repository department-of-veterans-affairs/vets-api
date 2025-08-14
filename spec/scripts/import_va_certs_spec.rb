# frozen_string_literal: true

require 'rails_helper'
require 'tmpdir'
require 'fileutils'

RSpec.describe 'import-va-certs.sh script' do
  let(:script_path) { Rails.root.join('import-va-certs.sh') }
  let(:temp_dir) { Dir.mktmpdir }
  let(:mock_cert_dir) { File.join(temp_dir, 'ca-certificates') }

  before do
    FileUtils.mkdir_p(mock_cert_dir)
  end

  after do
    FileUtils.rm_rf(temp_dir)
  end

  describe 'script execution' do
    context 'when script exists and is executable' do
      it 'exists in the root directory' do
        expect(File.exist?(script_path)).to be true
      end

      it 'is executable' do
        expect(File.executable?(script_path)).to be true
      end

      it 'starts with proper shebang' do
        first_line = File.open(script_path, &:readline).chomp
        expect(first_line).to eq('#! /usr/bin/env bash')
      end

      it 'has set -euo pipefail for safety' do
        script_content = File.read(script_path)
        expect(script_content).to include('set -euo pipefail')
      end
    end
  end

  describe 'certificate download fallback mechanism' do

    it 'implements HTTPS/HTTP fallback for VA certificates' do
      script_content = File.read(script_path)

      # Verify the script contains HTTPS first, then HTTP fallback for VA certs
      expect(script_content).to include('https://aia.pki.va.gov/PKI/AIA/VA/')
      expect(script_content).to include('http://aia.pki.va.gov/PKI/AIA/VA/')
      
      # Check that HTTPS comes before HTTP in the script (fallback pattern)
      https_position = script_content.index('https://aia.pki.va.gov/PKI/AIA/VA/')
      http_position = script_content.index('http://aia.pki.va.gov/PKI/AIA/VA/')
      
      expect(https_position).to be < http_position
      expect(script_content).to include('||') # Fallback operator between them
    end

    it 'verifies fallback mechanism structure without full execution' do
      script_content = File.read(script_path)

      # Verify the fallback structure is correctly implemented
      expect(script_content).to match(/wget.*https:\/\/aia\.pki\.va\.gov.*?\|\|.*wget.*http:\/\/aia\.pki\.va\.gov/m)
      
      # Verify DoD fallback is also present
      expect(script_content).to match(/curl.*https:\/\/dl\.dod\.cyber\.mil.*?\|\|.*curl.*http:\/\/dl\.dod\.cyber\.mil/m)
      
      # Verify certificate processing loop exists
      expect(script_content).to include('for cert in *.{cer,pem}')
      expect(script_content).to include('if file "${cert}" | grep \'PEM\'')
      expect(script_content).to include('cp "${cert}" "${cert}.crt"')
      expect(script_content).to include('openssl x509 -in "${cert}"')
    end
  end

  describe 'certificate processing' do
    let(:test_cert_dir) { File.join(temp_dir, 'test-certs') }

    before do
      FileUtils.mkdir_p(test_cert_dir)
    end

    it 'contains correct certificate processing logic' do
      script_content = File.read(script_path)

      # Verify the certificate processing logic is present
      expect(script_content).to include('for cert in *.{cer,pem}')
      expect(script_content).to include('if file "${cert}" | grep \'PEM\'')
      expect(script_content).to include('cp "${cert}" "${cert}.crt"')
      expect(script_content).to include('openssl x509 -in "${cert}" -inform der -outform pem -out "${cert}.crt"')
      expect(script_content).to include('rm "${cert}"')
    end

    it 'has correct DER to PEM conversion logic' do
      script_content = File.read(script_path)

      # Verify the script structure contains the correct commands for conversion
      expect(script_content).to include('openssl x509 -in "${cert}" -inform der -outform pem -out "${cert}.crt"')
      expect(script_content).to include('if file "${cert}" | grep \'PEM\'')
      
      # Verify the else branch for DER conversion is present
      expect(script_content).to match(/else.*openssl x509.*-inform der -outform pem/m)
    end
  end

  describe 'security and safety features' do
    it 'uses safe bash options' do
      script_content = File.read(script_path)
      expect(script_content).to include('set -euo pipefail')
    end

    it 'runs in a subshell to contain directory changes' do
      script_content = File.read(script_path)
      expect(script_content).to match(/^\(/)
      expect(script_content).to match(/\)$/)
    end

    it 'includes certificate verification at the end' do
      script_content = File.read(script_path)
      expect(script_content).to include("grep -iE '(VA-Internal|DigiCert)'")
    end

    it 'cleans up temporary files' do
      script_content = File.read(script_path)
      expect(script_content).to include('rm "${cert}"')
      expect(script_content).to include('rm eca_cert.pem')
    end
  end

  describe 'DoD ECA certificate handling' do
    it 'implements HTTPS/HTTP fallback for DoD certificates' do
      script_content = File.read(script_path)

      dod_section = script_content[/curl.*https:\/\/dl\.dod\.cyber\.mil.*?\|\|.*?curl.*http:\/\/dl\.dod\.cyber\.mil/m]

      expect(dod_section).to be_present
      expect(dod_section).to include('https://dl.dod.cyber.mil')
      expect(dod_section).to include('http://dl.dod.cyber.mil')
      expect(dod_section).to include('||') # Fallback operator
    end

    it 'processes DoD PKCS7 certificates' do
      script_content = File.read(script_path)

      expect(script_content).to include('unzip ./unclass-certificates_pkcs7_ECA.zip')
      expect(script_content).to include('openssl pkcs7 -inform DER')
      expect(script_content).to include('awk \'/BEGIN/{i++} {print > ("eca_cert" i ".pem")}\'')
    end
  end

  describe 'external certificate sources' do
    it 'downloads DigiCert certificates' do
      script_content = File.read(script_path)

      expect(script_content).to include('curl -LO https://cacerts.digicert.com/DigiCertTLSRSASHA2562020CA1-1.crt.pem')
      expect(script_content).to include('curl -LO https://digicert.tbs-certificats.com/DigiCertGlobalG2TLSRSASHA2562020CA1.crt')
    end
  end
end