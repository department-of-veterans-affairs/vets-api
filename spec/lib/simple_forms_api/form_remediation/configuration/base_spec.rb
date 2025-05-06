# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../../../lib/simple_forms_api/form_remediation/configuration/base'

RSpec.describe SimpleFormsApi::FormRemediation::Configuration::Base do
  let(:instance) { described_class.new }
  let(:caller_location) do
    double(path: 'modules/simple_forms_api/app/services/simple_forms_api/form_remediation/submission_archive.rb')
  end

  before { allow(instance).to receive(:caller_locations).and_return([caller_location]) }

  describe '#initialize' do
    it 'sets default values for instance variables' do
      expect(instance.id_type).to eq(:benefits_intake_uuid)
      expect(instance.include_manifest).to be(true)
      expect(instance.include_metadata).to be(false)
      expect(instance.parent_dir).to eq('')
      expect(instance.presign_s3_url).to be(true)
    end
  end

  describe '#submission_archive_class' do
    subject(:submission_archive_class) { instance.submission_archive_class }

    it 'returns the default submission archive class' do
      expect(submission_archive_class).to eq(SimpleFormsApi::FormRemediation::SubmissionArchive)
    end
  end

  describe '#s3_client' do
    subject(:s3_client) { instance.s3_client }

    it 'returns the default S3 client class' do
      expect(s3_client).to eq(SimpleFormsApi::FormRemediation::S3Client)
    end
  end

  describe '#remediation_data_class' do
    subject(:remediation_data_class) { instance.remediation_data_class }

    it 'returns the default remediation data class' do
      expect(remediation_data_class).to eq(SimpleFormsApi::FormRemediation::SubmissionRemediationData)
    end
  end

  describe '#uploader_class' do
    subject(:uploader_class) { instance.uploader_class }

    it 'returns the default uploader class' do
      expect(uploader_class).to eq(SimpleFormsApi::FormRemediation::Uploader)
    end
  end

  describe '#submission_type' do
    subject(:submission_type) { instance.submission_type }

    it 'returns the default FormSubmission type' do
      expect(submission_type).to eq(FormSubmission)
    end
  end

  describe '#attachment_type' do
    subject(:attachment_type) { instance.attachment_type }

    it 'returns the default attachment type' do
      expect(attachment_type).to eq(PersistentAttachment)
    end
  end

  describe '#temp_directory_path' do
    subject(:temp_directory_path) { instance.temp_directory_path }

    it 'returns a unique temporary directory path' do
      expect(temp_directory_path).to start_with(Rails.root.join('tmp', '').to_s)
      expect(temp_directory_path).to match(%r{-archive/$})
    end
  end

  describe '#s3_settings' do
    subject(:s3_settings) { instance.s3_settings }

    it 'raises NotImplementedError' do
      expect { s3_settings }.to raise_error(NotImplementedError, 'Class must implement s3_settings method')
    end
  end

  describe '#log_info' do
    subject(:log_info) { instance.log_info('Test message', extra: 'detail') }

    before do
      allow(Rails.logger).to receive(:info)
      log_info
    end

    it 'logs an info message with the provided details' do
      expect(Rails.logger).to have_received(:info).with(
        hash_including(message: a_string_matching(/Test message/), extra: 'detail')
      )
    end
  end

  describe '#log_error' do
    subject(:log_error) { instance.log_error('Error occurred', error, extra: 'info') }

    let(:error) { StandardError.new('Test error') }
    let(:backtrace) { ['/path/to/file.rb:42:in `method_name`'] }
    let(:hash) { { backtrace:, error: 'Test error', extra: 'info', message: a_string_including('Error occurred') } }

    before do
      error.set_backtrace(backtrace)
      allow(Rails.logger).to receive(:error)
      log_error
    end

    it 'logs an error message with the provided details' do
      expect(Rails.logger).to have_received(:error).with(hash)
    end
  end

  describe '#handle_error' do
    subject(:handle_error) { instance.handle_error('Handling error', error, additional: 'data') }

    let(:error) { StandardError.new('Test error') }

    before { allow(instance).to receive(:log_error) }

    it 'logs the error and raises a SimpleFormsApi::FormRemediation::Error' do
      expect { handle_error }.to(
        raise_error(SimpleFormsApi::FormRemediation::Error, a_string_including('Handling error'))
      )
      expect(instance).to have_received(:log_error).with('Handling error', error, additional: 'data')
    end
  end

  describe '#caller_class' do
    before { allow(instance).to receive(:caller_locations).and_return([caller_location]) }

    context 'when caller class is found' do
      it 'returns the correct class name from the caller stack' do
        expect(instance.send(:caller_class)).to eq('SimpleFormsApi::FormRemediation::SubmissionArchive')
      end
    end

    context 'when caller class is not found' do
      let(:caller_location) { double(path: 'modules/nonexistent/app/services/unknown_class.rb') }

      it 'falls back to SimpleFormsApi::FormRemediation when class name is not found' do
        expect(instance.send(:caller_class)).to eq('SimpleFormsApi::FormRemediation')
      end
    end
  end
end
