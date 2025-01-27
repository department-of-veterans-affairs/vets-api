# frozen_string_literal: true

require 'rails_helper'
require 'simple_forms_api/form_remediation/configuration/vff_config'

RSpec.describe SimpleFormsApi::FormRemediation::UploadRetryJob, type: :worker do
  let(:file) { instance_double(CarrierWave::SanitizedFile, filename: 'test_file.txt') }
  let(:directory) { 'test/directory' }
  let(:s3_settings) { OpenStruct.new(region: 'us-east-1') }
  let(:config) do
    instance_double(SimpleFormsApi::FormRemediation::Configuration::VffConfig, uploader_class:, s3_settings:)
  end
  let(:uploader_class) { class_double(SimpleFormsApi::FormRemediation::Uploader) }
  let(:uploader_instance) { instance_double(SimpleFormsApi::FormRemediation::Uploader) }
  let(:s3_client_instance) { instance_double(Aws::S3::Client) }

  before do
    allow(uploader_class).to receive(:new).with(directory:, config:).and_return(uploader_instance)
    allow(StatsD).to receive(:increment)
    allow(Aws::S3::Client).to receive(:new).and_return(s3_client_instance)
    allow(Rails.logger).to receive(:info)
    allow(Rails.logger).to receive(:error)
  end

  describe '#perform' do
    context 'when the upload succeeds' do
      it 'uploads the file and increments the StatsD counter' do
        allow(uploader_instance).to receive(:store!).with(file)

        described_class.new.perform(file, directory, config)

        expect(uploader_instance).to have_received(:store!).with(file)
        expect(StatsD).to have_received(:increment).with('api.simple_forms_api.upload_retry_job.total')
      end
    end

    context 'when the upload fails with a ServiceError' do
      before do
        allow(uploader_instance).to receive(:store!).and_raise(Aws::S3::Errors::ServiceError.new(nil, 'Service error'))
      end

      context 'and the service is available' do
        before do
          allow(s3_client_instance).to receive(:list_buckets).and_return(true)
        end

        it 'raises the error' do
          expect do
            described_class.new.perform(file, directory, config)
          end.to raise_error(Aws::S3::Errors::ServiceError)

          expect(StatsD).to have_received(:increment).with('api.simple_forms_api.upload_retry_job.total')
        end
      end

      context 'and the service is unavailable' do
        before do
          allow(s3_client_instance).to(
            receive(:list_buckets).and_return(true)
                                  .and_raise(Aws::S3::Errors::ServiceError.new(nil, 'Service error'))
          )
          allow(described_class).to receive(:perform_in)
        end

        it 'retries the job later and logs the retry' do
          described_class.new.perform(file, directory, config)

          expect(described_class).to have_received(:perform_in)
          expect(Rails.logger).to have_received(:info).with(
            'S3 service unavailable. Retrying upload later for test_file.txt.'
          )
        end
      end
    end
  end

  describe 'sidekiq_retries_exhausted' do
    it 'logs the retries exhausted error and increments the StatsD counter' do
      exception = Aws::S3::Errors::ServiceError.new(%w[backtrace1 backtrace2], 'Service error')

      allow(StatsD).to receive(:increment).with('api.simple_forms_api.upload_retry_job.retries_exhausted')
      allow(Rails.logger).to receive(:error).with(
        'SimpleFormsApi::FormRemediation::UploadRetryJob retries exhausted',
        hash_including(exception: "#{exception.class} - #{exception.message}")
      )

      job = described_class.new
      job.sidekiq_retries_exhausted_block.call('Oops', exception)

      expect(StatsD).to have_received(:increment).with('api.simple_forms_api.upload_retry_job.retries_exhausted')
      expect(Rails.logger).to have_received(:error).with(
        'SimpleFormsApi::FormRemediation::UploadRetryJob retries exhausted',
        hash_including(exception: "#{exception.class} - #{exception.message}")
      )
    end
  end
end
