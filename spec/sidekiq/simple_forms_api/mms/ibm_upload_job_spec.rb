# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/testing'
require 'ibm/service'

RSpec.describe SimpleFormsApi::Mms::IbmUploadJob, type: :job do
  let(:ibm_payload) { { key: 'value' } }
  let(:form_number) { '12345' }
  let(:confirmation_number) { '67890' }

  let(:ibm_service) { instance_double(Ibm::Service) }
  let(:job) { described_class.new }

  before do
    allow(Ibm::Service).to receive(:new).and_return(ibm_service)
    allow(Rails.logger).to receive(:info)
    allow(Rails.logger).to receive(:error)
  end

  describe '#perform' do
    context 'when IBM upload is successful' do
      let(:response) { instance_double(Faraday::Response, status: 200) }

      before do
        allow(ibm_service).to receive(:upload_form).and_return(response)
      end

      it 'logs the success message' do
        expect(Rails.logger).to receive(:info).with(
          'Simple Forms API - MMS submission complete',
          hash_including(guid: confirmation_number, form_number:)
        )

        described_class.new.perform(ibm_payload, form_number, confirmation_number)
      end

      it 'does not log an error and does not raise' do
        expect do
          job.perform(ibm_payload, form_number, confirmation_number)
        end.not_to raise_error

        expect(Rails.logger).not_to have_received(:error)
      end
    end

    context 'when IBM upload returns no response' do
      before do
        allow(ibm_service).to receive(:upload_form).and_return(nil)
      end

      it 'logs the error and raises the exception' do
        expect do
          job.perform(ibm_payload, form_number, confirmation_number)
        end.to raise_error(StandardError, 'IBM upload returned no response')

        expect(Rails.logger).to have_received(:error).with(
          'Simple Forms API - MMS submission failed: IBM upload returned no response',
          hash_including(
            guid: confirmation_number,
            form_number:
          )
        )
      end
    end

    context 'when IBM upload returns a non-200 status code' do
      let(:response) { instance_double(Faraday::Response, status: 500) }

      before do
        allow(ibm_service).to receive(:upload_form).and_return(response)
      end

      it 'logs the error and raises the exception' do
        expect do
          job.perform(ibm_payload, form_number, confirmation_number)
        end.to raise_error(StandardError, 'IBM upload returned status 500')

        expect(Rails.logger).to have_received(:error).with(
          'Simple Forms API - MMS submission failed: IBM upload returned status 500',
          hash_including(
            guid: confirmation_number,
            form_number:
          )
        )
      end
    end

    context 'when IBM upload itself raises an exception' do
      before do
        allow(ibm_service).to receive(:upload_form)
          .and_raise(StandardError, 'Upload error')
      end

      it 'logs the error message and re-raises the exception' do
        expect do
          job.perform(ibm_payload, form_number, confirmation_number)
        end.to raise_error(StandardError, 'Upload error')

        expect(Rails.logger).to have_received(:error).with(
          'Simple Forms API - MMS submission failed: Upload error',
          hash_including(
            guid: confirmation_number,
            form_number:
          )
        )
      end
    end

    context 'when job retries are exhausted' do
      it 'logs the retries exhausted message' do
        msg = { 'args' => [ibm_payload, form_number, confirmation_number] }
        ex = StandardError.new('Upload error')

        expect(Rails.logger).to receive(:error).with(
          'Sidekiq retries exhausted for SimpleForms::API::MMS::IbmUploadJob - StandardError: Upload error',
          guid: confirmation_number,
          form_number:
        )

        described_class.sidekiq_retries_exhausted_block.call(msg, ex)
      end
    end
  end
end
