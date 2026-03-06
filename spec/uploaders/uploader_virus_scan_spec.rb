# frozen_string_literal: true

require 'rails_helper'

describe UploaderVirusScan, :uploader_helpers do
  class UploaderVirusScanTest < CarrierWave::Uploader::Base
    include UploaderVirusScan
  end
  let(:file) { Rack::Test::UploadedFile.new('spec/fixtures/files/va.gif', 'image/gif') }

  def store_image
    UploaderVirusScanTest.new.store!(file)
  end

  context 'in production' do
    stub_virus_scan

    context 'with no virus' do
      it 'runs the virus scan' do
        expect(Rails.env).to receive(:production?).and_return(true)

        store_image
      end
    end

    context 'with a virus' do
      before do
        allow(Common::VirusScan).to receive(:scan).and_return(false)
        allow(Rails.env).to receive(:production?).and_return(true)
      end

      it 'raises an error' do
        expect(file).to receive(:delete)

        expect { store_image }.to raise_error(
          UploaderVirusScan::VirusFoundError,
          'virus or malware detected'
        )
      end

      it 'does not leak the file path in the error message' do
        allow(file).to receive(:delete)

        expect { store_image }.to raise_error(UploaderVirusScan::VirusFoundError) do |error|
          expect(error.message).not_to match(%r{clamav_tmp/})
        end
      end
    end

    describe 'AU-2 audit logging via Common::VirusScan' do
      before do
        allow(Rails.env).to receive(:production?).and_return(true)
      end

      it 'passes upload_context to Common::VirusScan.scan' do
        allow(Common::VirusScan).to receive(:scan).and_return(true)

        store_image

        expect(Common::VirusScan).to have_received(:scan).with(
          an_instance_of(String),
          upload_context: 'UploaderVirusScanTest'
        )
      end

      it 'delegates audit logging to Common::VirusScan for virus detection' do
        allow(Common::VirusScan).to receive(:scan).and_return(false)
        allow(file).to receive(:delete)

        expect { store_image }.to raise_error(UploaderVirusScan::VirusFoundError)

        expect(Common::VirusScan).to have_received(:scan).with(
          an_instance_of(String),
          upload_context: 'UploaderVirusScanTest'
        )
      end
    end

    describe 'AU-2 audit log integration' do
      let(:test_remote_ip) { '10.0.0.42' }
      let(:scan_result_hash) { { safe: false, virus_name: 'Win.Test.EICAR_HDB-1' } }

      before do
        allow(Rails.env).to receive(:production?).and_return(true)
        allow(Common::VirusScan).to receive(:scan).and_call_original
        allow(File).to receive(:chmod).and_call_original
        RequestStore.store['additional_request_attributes'] = { 'remote_ip' => test_remote_ip }
        allow(Common::VirusScan).to receive(:mock_enabled?).and_return(false)
        allow(ClamAV::PatchClient).to receive(:new).and_return(
          instance_double(ClamAV::PatchClient, scan_with_result: scan_result_hash)
        )
      end

      after do
        RequestStore.store['additional_request_attributes'] = nil
      end

      it 'emits a ClamAV Virus Scan Audit log with all AU-2 fields when a virus is detected' do
        allow(Rails.logger).to receive(:info).and_call_original
        allow(file).to receive(:delete)

        expect { store_image }.to raise_error(UploaderVirusScan::VirusFoundError)

        expect(Rails.logger).to have_received(:info).with(
          'ClamAV Virus Scan Audit',
          hash_including(
            event: 'virus_scan',
            ip_address: test_remote_ip,
            scan_result: 'infected',
            virus_name: 'Win.Test.EICAR_HDB-1',
            file_name: match(/\A[a-f0-9]{64}\z/),
            file_size: an_instance_of(Integer),
            scan_duration_ms: an_instance_of(Float),
            upload_context: 'UploaderVirusScanTest'
          )
        )
      end

      it 'emits the audit log for clean scans too' do
        allow(ClamAV::PatchClient).to receive(:new).and_return(
          instance_double(ClamAV::PatchClient, scan_with_result: { safe: true, virus_name: nil })
        )
        allow(Rails.logger).to receive(:info).and_call_original

        store_image

        expect(Rails.logger).to have_received(:info).with(
          'ClamAV Virus Scan Audit',
          hash_including(scan_result: 'clean', virus_name: nil)
        )
      end
    end
  end
end
