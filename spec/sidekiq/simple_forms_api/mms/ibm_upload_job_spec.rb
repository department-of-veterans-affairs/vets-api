require 'rails_helper'
require 'sidekiq/testing'
require 'ibm/service'

RSpec.describe SimpleFormsApi::Mms::IbmUploadJob, type: :job do
  let(:ibm_payload) { double('IbmPayload', to_json: '{"key":"value"}') }
  let(:form_number) { '12345' }
  let(:confirmation_number) { '67890' }
  let(:ibm_service) { instance_double(Ibm::Service) }

  before do
    allow(Ibm::Service).to receive(:new).and_return(ibm_service)
  end

  describe '#perform' do
    context 'when IBM upload is successful' do
      before do
        allow(ibm_service).to receive(:upload_form).and_return(true) # Simulating a successful response
      end

      it 'logs the success message' do
           expect(Rails.logger).to receive(:info).with(
          'Simple Forms API - MMS submission complete', 
          hash_including(guid: confirmation_number, form_number: form_number)
        )

        described_class.new.perform(ibm_payload, form_number, confirmation_number)
      end
    end

    context 'when IBM upload fails with no response' do
      before do
        allow(ibm_service).to receive(:upload_form).and_return(nil) # Simulating failure with no response
      end

      it 'logs the error message indicating no response from IBM' do
        expect(Rails.logger).to receive(:error).with(
          'Simple Forms API - MMS submission failed: IBM upload returned no response',
          guid: confirmation_number,
          form_number: form_number
        )

        described_class.new.perform(ibm_payload, form_number, confirmation_number)
      end
    end

    context 'when IBM upload raises an exception' do
      before do
        allow(ibm_service).to receive(:upload_form).and_raise(StandardError.new('Upload error')) # Simulating an exception
      end

      it 'logs the error message with the exception message' do
        expect(Rails.logger).to receive(:error).with(
          'Simple Forms API - MMS submission failed: Upload error',
          guid: confirmation_number,
          form_number: form_number
        )

        described_class.new.perform(ibm_payload, form_number, confirmation_number)
      end
    end
  end
end
