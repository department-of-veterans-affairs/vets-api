# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/testing'
require 'ibm/service'

RSpec.describe SimpleFormsApi::Mms::IbmUploadJob, type: :job do
  let(:ibm_payload) { double('IbmPayload', to_json: '{"key":"value"}') }
  let(:form_number) { '12345' }
  let(:confirmation_number) { '67890' }
  let(:ibm_service) { instance_double(Ibm::Service) }
  let(:faraday_response) { instance_double(Faraday::Response, status: 500, body: 'Internal Server Error') }
  let(:job) { described_class.new }

  before do
    allow(Ibm::Service).to receive(:new).and_return(ibm_service)
  end

  describe '#perform' do
    context 'when IBM upload is successful' do
      before do
        allow(ibm_service).to receive(:upload_form).and_return(faraday_response)
        allow(faraday_response).to receive(:status).and_return(200) # Simulating a successful 200 response
      end

      it 'logs the success message' do
        expect(Rails.logger).to receive(:info).with(
          'Simple Forms API - MMS submission complete',
          hash_including(guid: confirmation_number, form_number:)
        )

        described_class.new.perform(ibm_payload, form_number, confirmation_number)
      end
    end

    context 'when IBM upload fails with no response' do
      before do
        allow(ibm_service).to receive(:upload_form).and_return(nil)
      end

      it 'logs the error message indicating no response from IBM' do
        expect(Rails.logger).to receive(:error).with(
          'Simple Forms API - MMS submission failed: IBM upload returned no response',
          guid: confirmation_number,
          form_number:
        )

        described_class.new.perform(ibm_payload, form_number, confirmation_number)
      end
    end

    context 'when IBM upload returns a non-200 status code' do
      before do
        allow(ibm_service).to receive(:upload_form).and_return(faraday_response)
        allow(faraday_response).to receive(:status).and_return(500)
      end

      it 'logs the error message with the response status' do
        expect(Rails.logger).to receive(:error).with(
          'Simple Forms API - MMS submission failed: IBM upload returned status 500',
          guid: confirmation_number,
          form_number:
        )

        described_class.new.perform(ibm_payload, form_number, confirmation_number)
      end
    end

    context 'when IBM upload raises an exception' do
      before do
        allow(Ibm::Service).to receive(:new).and_return(ibm_service)

        allow(ibm_service).to receive(:upload_form).and_raise(
          StandardError.new('Upload error')
        )
      end

      it 'logs the error message and re-raises the exception' do
        expect(Rails.logger).to receive(:error).with(
          'Simple Forms API - MMS submission failed: Upload error',
          guid: confirmation_number,
          form_number:
        )

        expect do
          described_class.new.perform(
            ibm_payload,
            form_number,
            confirmation_number
          )
        end.to raise_error(StandardError, 'Upload error')
      end
    end

    context 'when job retries are exhausted' do
      let(:ibm_payload) { { some: 'payload' } }
      let(:form_number) { '21-4140' }
      let(:confirmation_number) { 'abc123' }

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
