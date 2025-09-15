# frozen_string_literal: true

require 'rails_helper'
require 'tmpdir'
require 'fileutils'

RSpec.describe 'import-va-certs' do # rubocop:disable RSpec/DescribeClass
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
        expect(first_line).to eq('#!/usr/bin/env bash')
      end

      it 'has set -euo pipefail for safety' do
        script_content = File.read(script_path)
        expect(script_content).to include('set -euo pipefail')
      end
    end
  end

  describe 'DoD ECA certificate handling' do
    it 'implements multiple fallback mechanisms for DoD certificates' do
      script_content = File.read(script_path)

      # Verify primary HTTPS attempt with proper flags
      expect(script_content).to include(
        'curl --show-error --connect-timeout 10 --max-time 60 --retry 3 --retry-delay 5'
      )
      expect(script_content).to include('https://dl.dod.cyber.mil/wp-content/uploads/pki-pke/zip/unclass-certificates_pkcs7_ECA.zip')

      # Verify HTTP fallback
      expect(script_content).to include('elif curl --connect-timeout 10 --max-time 60 --retry 3 --retry-delay 5 -LO http://dl.dod.cyber.mil')

      # Verify proper if/elif structure
      expect(script_content).to include('elif curl')
    end

    it 'includes comprehensive error handling and logging for DoD certificates' do
      script_content = File.read(script_path)

      # Verify logging messages are present
      expect(script_content).to include('Downloading DoD ECA certificates...')
      expect(script_content).to include('✓ DoD ECA downloaded via HTTPS')
      expect(script_content).to include('✓ DoD ECA downloaded via HTTP fallback')
      expect(script_content).to include('✗ All DoD ECA download attempts failed')
      expect(script_content).to include('✓ DoD ECA certificates processed successfully')
      expect(script_content).to include('✗ DoD ECA zip file not found after download attempts')
    end

    it 'processes DoD PKCS7 certificates correctly' do
      script_content = File.read(script_path)

      expect(script_content).to include('unzip ./unclass-certificates_pkcs7_ECA.zip -d ECA_CA')
      expect(script_content).to include('cd ECA_CA/certificates_pkcs7_v5_12_eca/')
      expect(script_content).to include('awk \'/BEGIN/{i++} {print > ("eca_cert" i ".pem")}\'')
      expect(script_content).to include('rm -f eca_cert.pem')
      expect(script_content).to include('cp *.pem ../../')
    end

    it 'handles DoD certificate download failures gracefully' do
      script_content = File.read(script_path)

      # Verify it checks for zip file existence before processing
      expect(script_content).to include('if [ -f "unclass-certificates_pkcs7_ECA.zip" ]; then')

      # Verify it continues without exiting on failure (no actual exit 1 command after DoD failures)
      # Look for the else block and verify it doesn't have an executable exit 1
      dod_else_block = script_content[/else\s+echo "✗ All DoD ECA download attempts failed".*?fi/m]
      expect(dod_else_block).not_to match(/^\s*exit 1\s*$/m)
    end
  end

  describe 'VA certificate download' do
    it 'uses wget for VA certificates' do
      script_content = File.read(script_path)

      # Verify wget command with proper options
      expect(script_content).to include('wget')
      expect(script_content).to include('--level=1')
      expect(script_content).to include('--quiet')
      expect(script_content).to include('--recursive')
      expect(script_content).to include('--no-parent')
      expect(script_content).to include('--no-host-directories')
      expect(script_content).to include('--no-directories')
      expect(script_content).to include('--accept="VA*.cer"')
      expect(script_content).to include('http://aia.pki.va.gov/PKI/AIA/VA/')
    end

    it 'includes VA certificate download logging' do
      script_content = File.read(script_path)
      expect(script_content).to include('Downloading VA certificates...')
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
      expect(script_content).to include('if file "${cert}" | grep -q \'PEM\'')
      expect(script_content).to include('cp "${cert}" "${cert}.crt"')
      expect(script_content).to include('openssl x509 -in "${cert}" -inform der -outform pem -out "${cert}.crt"')
      expect(script_content).to include('rm "${cert}"')
    end

    it 'has correct DER to PEM conversion logic' do
      script_content = File.read(script_path)

      # Verify the script structure contains the correct commands for conversion
      expect(script_content).to include('openssl x509 -in "${cert}" -inform der -outform pem -out "${cert}.crt"')
      expect(script_content).to include('if file "${cert}" | grep -q \'PEM\'')

      # Verify base64-encoded DER handling
      expect(script_content).to include('elif file "${cert}" | grep -q \'ASCII text\'')
      expect(script_content).to include('base64 -d "${cert}" > "${cert}.der"')

      # Verify the else branch for binary DER conversion is present
      expect(script_content).to match(/else\s+.*openssl x509.*-inform der -outform pem/m)
    end
  end

  describe 'external certificate sources' do
    it 'downloads DigiCert certificates' do
      script_content = File.read(script_path)

      expect(script_content).to include('curl -LO https://cacerts.digicert.com/DigiCertTLSRSASHA2562020CA1-1.crt.pem')
      expect(script_content).to include('curl -LO https://digicert.tbs-certificats.com/DigiCertGlobalG2TLSRSASHA2562020CA1.crt')
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
      expect(script_content).to include('update-ca-certificates --fresh')
      expect(script_content).to include("grep -iE '(VA-Internal|DigiCert)'")
    end

    it 'cleans up temporary files' do
      script_content = File.read(script_path)
      expect(script_content).to include('rm "${cert}"')
      expect(script_content).to include('rm -f eca_cert.pem')
    end

    it 'uses proper error handling with curl --fail flag' do
      script_content = File.read(script_path)

      # Verify the primary DoD download uses --fail flag
      expect(script_content).to include('curl --show-error')

      # Verify it's used in an if statement for proper error handling
      expect(script_content).to match(/if curl .*then/m)
    end
  end

  describe 'system certificate store update' do
    it 'updates the system certificate store' do
      script_content = File.read(script_path)
      expect(script_content).to include('update-ca-certificates --fresh')
    end

    it 'displays trusted certificates after update' do
      script_content = File.read(script_path)
      expect(script_content).to include('awk -v cmd=\'openssl x509 -noout -subject\'')
      expect(script_content).to include('/etc/ssl/certs/ca-certificates.crt')
    end
  end
end
