# frozen_string_literal: true

require 'rails_helper'
require 'shrine/plugins/validate_virus_free'

describe Shrine::Plugins::ValidateVirusFree do
  describe '#validate_virus_free' do
    let(:klass) do
      Class.new do
        include Shrine::Plugins::ValidateVirusFree::AttacherMethods
        def get
          'stuff'
        end

        def errors
          @errors ||= []
        end

        def record
          nil
        end
      end
    end

    let(:instance) { klass.new }

    before do
      allow_any_instance_of(klass).to receive(:get)
        .and_return(instance_double(Shrine::UploadedFile, download: instance_double(File, path: 'foo/bar.jpg')))

      allow(File).to receive(:chmod).with(0o640, 'foo/bar.jpg').and_return(1)
    end

    context 'with errors' do
      before do
        allow(Common::VirusScan).to receive(:scan).and_return(false)
      end

      context 'while in development' do
        it 'logs an error message if clamd is not running' do
          expect(Rails.env).to receive(:development?).and_return(true)
          expect(Rails.logger).to receive(:error).with(/PLEASE START CLAMD/)
          result = instance.validate_virus_free(message: 'nodename nor servname provided')
          expect(result).to be(true)
        end
      end

      context 'with the default error message' do
        it 'adds an error if clam scan returns not safe' do
          result = instance.validate_virus_free
          expect(result).to be(false)
          expect(instance.errors).to include('virus or malware detected')
        end
      end

      context 'with a custom error message' do
        let(:message) { 'oh noes!' }

        it 'adds an error with a custom error message if clam scan returns not safe' do
          result = instance.validate_virus_free(message:)
          expect(result).to be(false)
          expect(instance.errors).to eq(['oh noes!'])
        end
      end
    end

    context 'it returns safe' do
      before do
        allow(Common::VirusScan).to receive(:scan).and_return(true)
      end

      it 'does not add an error if clam scan returns safe' do
        allow_any_instance_of(ClamAV::PatchClient).to receive(:safe?).and_return(true)

        expect(instance).not_to receive(:add_error_msg)
        result = instance.validate_virus_free
        expect(result).to be(true)
      end
    end

    describe 'virus detection logging (AU-2)' do
      before do
        allow(Common::VirusScan).to receive(:scan).and_return(false)
      end

      let(:test_remote_ip) { '10.0.0.42' }

      before do
        RequestStore.store['additional_request_attributes'] = { 'remote_ip' => test_remote_ip }
      end

      it 'emits a structured warn log when a virus is detected' do
        expect(Rails.logger).to receive(:warn).with(
          'Virus or malware detected during upload scan',
          hash_including(
            scan_result: 'virus_detected',
            remote_ip: test_remote_ip,
            file_name_hash: an_instance_of(String),
            upload_context: nil
          )
        )

        instance.validate_virus_free
      end

      it 'hashes the file name instead of logging it in plaintext' do
        allow(Rails.logger).to receive(:warn)

        instance.validate_virus_free

        expect(Rails.logger).to have_received(:warn).with(
          'Virus or malware detected during upload scan',
          hash_including(file_name_hash: match(/\A[a-f0-9]{64}\z/))
        )
      end

      it 'does not include user_uuid in the log payload' do
        RequestStore.store['additional_request_attributes'] =
          { 'remote_ip' => test_remote_ip, 'user_uuid' => 'some-uuid' }

        allow(Rails.logger).to receive(:warn)

        instance.validate_virus_free

        expect(Rails.logger).to have_received(:warn).with(
          'Virus or malware detected during upload scan',
          hash_not_including(:user_uuid)
        )
      end

      it 'includes the upload_context from the record class name' do
        record_double = instance_double('FormSubmissionAttempt', class: FormSubmissionAttempt)
        allow(instance).to receive(:record).and_return(record_double)

        allow(Rails.logger).to receive(:warn)

        instance.validate_virus_free

        expect(Rails.logger).to have_received(:warn).with(
          'Virus or malware detected during upload scan',
          hash_including(upload_context: 'FormSubmissionAttempt')
        )
      end

      it 'gracefully handles missing RequestStore context' do
        RequestStore.store['additional_request_attributes'] = nil

        allow(Rails.logger).to receive(:warn)

        instance.validate_virus_free

        expect(Rails.logger).to have_received(:warn).with(
          'Virus or malware detected during upload scan',
          hash_including(remote_ip: nil)
        )
      end

      it 'does not log when the scan result is safe' do
        allow(Common::VirusScan).to receive(:scan).and_return(true)

        expect(Rails.logger).not_to receive(:warn)

        instance.validate_virus_free
      end
    end
  end
end
