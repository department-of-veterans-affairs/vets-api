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

      it 'emits a structured info log when scan is clean' do
        allow(Rails.env).to receive(:production?).and_return(true)
        allow(Rails.logger).to receive(:info)

        store_image

        expect(Rails.logger).to have_received(:info).with(
          'ClamAV scan completed',
          hash_including(
            scan_result: 'clean',
            file_name_hash: an_instance_of(String),
            file_size: file.size,
            content_type: 'image/gif',
            scan_duration_ms: an_instance_of(Integer),
            upload_context: 'UploaderVirusScanTest'
          )
        )
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

      it 'emits a structured warn log when virus is detected' do
        allow(file).to receive(:delete)
        allow(Rails.logger).to receive(:warn)

        expect { store_image }.to raise_error(UploaderVirusScan::VirusFoundError)

        expect(Rails.logger).to have_received(:warn).with(
          'ClamAV scan completed',
          hash_including(
            scan_result: 'virus_detected',
            virus_name: nil,
            file_name_hash: an_instance_of(String),
            file_size: file.size,
            content_type: 'image/gif',
            upload_context: 'UploaderVirusScanTest'
          )
        )
      end

      it 'hashes the file name instead of logging it in plaintext' do
        allow(file).to receive(:delete)
        allow(Rails.logger).to receive(:warn)

        expect { store_image }.to raise_error(UploaderVirusScan::VirusFoundError)

        expect(Rails.logger).to have_received(:warn).with(
          'ClamAV scan completed',
          hash_including(file_name_hash: match(/\A[a-f0-9]{64}\z/))
        )
      end

      it 'includes ip_address from RequestStore when available' do
        RequestStore.store['additional_request_attributes'] = { 'remote_ip' => '10.0.0.42' }
        allow(file).to receive(:delete)
        allow(Rails.logger).to receive(:warn)

        expect { store_image }.to raise_error(UploaderVirusScan::VirusFoundError)

        expect(Rails.logger).to have_received(:warn).with(
          'ClamAV scan completed',
          hash_including(ip_address: '10.0.0.42')
        )
      end

      it 'does not include user_uuid in the log payload' do
        RequestStore.store['additional_request_attributes'] =
          { 'remote_ip' => '10.0.0.42', 'user_uuid' => 'some-uuid' }
        allow(file).to receive(:delete)
        allow(Rails.logger).to receive(:warn)

        expect { store_image }.to raise_error(UploaderVirusScan::VirusFoundError)

        expect(Rails.logger).to have_received(:warn).with(
          'ClamAV scan completed',
          hash_not_including(:user_uuid)
        )
      end

      it 'gracefully handles missing RequestStore context' do
        RequestStore.store['additional_request_attributes'] = nil
        allow(file).to receive(:delete)
        allow(Rails.logger).to receive(:warn)

        expect { store_image }.to raise_error(UploaderVirusScan::VirusFoundError)

        expect(Rails.logger).to have_received(:warn).with(
          'ClamAV scan completed',
          hash_including(ip_address: nil)
        )
      end
    end
  end
end
