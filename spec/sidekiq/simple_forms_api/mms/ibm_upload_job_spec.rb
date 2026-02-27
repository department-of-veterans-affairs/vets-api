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
        allow(ibm_service).to receive(:upload_form).and_raise(StandardError.new('Upload error'))
      end

      it 'logs the error message with the exception message' do
        expect(Rails.logger).to receive(:error).with(
          'Simple Forms API - MMS submission failed: Upload error',
          guid: confirmation_number,
          form_number:
        )

        described_class.new.perform(ibm_payload, form_number, confirmation_number)
      end
    end

    context 'when job retries are exhausted' do
      before do
        allow_any_instance_of(SimpleFormsApi::Mms::IbmUploadJob)
          .to receive(:perform)
          .and_raise(StandardError.new('Upload error'))

        SimpleFormsApi::Mms::IbmUploadJob.sidekiq_options retry: 3

        allow_any_instance_of(SimpleFormsApi::Mms::IbmUploadJob)
          .to receive(:sidekiq_retries_exhausted)
          .and_call_original
      end

      it 'logs the retries exhausted message' do
        expect(Rails.logger).to receive(:error).with(
          'Sidekiq: Simple Forms API - MMS IbmUploadJob retries exhausted',
          guid: confirmation_number,
          form_number:
        )

        # Expect job to raise an error after retries
        expect do
          SimpleFormsApi::Mms::IbmUploadJob.new.perform(ibm_payload, form_number, confirmation_number)
        end.to raise_error(StandardError)
        # Simulate job retries exhaustion directly by invoking sidekiq_retries_exhausted
        job = SimpleFormsApi::Mms::IbmUploadJob.new
        msg = { 'args' => [nil, form_number, confirmation_number] }
        job.sidekiq_retries_exhausted(msg)
      end
    end
  end
end
