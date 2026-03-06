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

        it 'does not leak the file path in the error message' do
          instance.validate_virus_free
          expect(instance.errors).not_to include(a_string_matching(%r{clamav_tmp/}))
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

    describe 'AU-2 audit logging via Common::VirusScan' do
      it 'passes upload_context to Common::VirusScan.scan' do
        allow(Common::VirusScan).to receive(:scan).and_return(true)

        instance.validate_virus_free

        expect(Common::VirusScan).to have_received(:scan).with(
          an_instance_of(String),
          upload_context: nil
        )
      end

      it 'passes the record class name as upload_context' do
        record_double = instance_double(FormSubmissionAttempt, class: FormSubmissionAttempt)
        allow(instance).to receive(:record).and_return(record_double)
        allow(Common::VirusScan).to receive(:scan).and_return(true)

        instance.validate_virus_free

        expect(Common::VirusScan).to have_received(:scan).with(
          an_instance_of(String),
          upload_context: 'FormSubmissionAttempt'
        )
      end
    end

    describe 'AU-2 audit log integration' do
      let(:test_remote_ip) { '10.0.0.42' }
      let(:scan_result_hash) { { safe: false, virus_name: 'Win.Test.EICAR_HDB-1' } }

      before do
        allow(File).to receive(:chmod).and_call_original
        RequestStore.store['additional_request_attributes'] = { 'remote_ip' => test_remote_ip }
        allow(Common::VirusScan).to receive(:mock_enabled?).and_return(false)
        allow(ClamAV::PatchClient).to receive(:new).and_return(
          instance_double(ClamAV::PatchClient, scan_with_result: scan_result_hash)
        )
      end

      it 'emits a ClamAV Virus Scan Audit log with all AU-2 fields when a virus is detected' do
        allow(Rails.logger).to receive(:info).and_call_original

        instance.validate_virus_free

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
            upload_context: nil
          )
        )
      end

      it 'includes upload_context in the audit log when a record is present' do
        record_double = instance_double(FormSubmissionAttempt, class: FormSubmissionAttempt)
        allow(instance).to receive(:record).and_return(record_double)
        allow(Rails.logger).to receive(:info).and_call_original

        instance.validate_virus_free

        expect(Rails.logger).to have_received(:info).with(
          'ClamAV Virus Scan Audit',
          hash_including(upload_context: 'FormSubmissionAttempt')
        )
      end

      it 'emits the audit log for clean scans too' do
        allow(ClamAV::PatchClient).to receive(:new).and_return(
          instance_double(ClamAV::PatchClient, scan_with_result: { safe: true, virus_name: nil })
        )
        allow(Rails.logger).to receive(:info).and_call_original

        instance.validate_virus_free

        expect(Rails.logger).to have_received(:info).with(
          'ClamAV Virus Scan Audit',
          hash_including(scan_result: 'clean', virus_name: nil)
        )
      end
    end
  end
end
