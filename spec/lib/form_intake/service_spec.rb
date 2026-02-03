# frozen_string_literal: true

require 'rails_helper'
require 'form_intake/service'

RSpec.describe FormIntake::Service do
  let(:service) { described_class.new }
  let(:payload) { { form_number: '21P-601', data: {} } }
  let(:uuid) { SecureRandom.uuid }

  describe '#submit_form_data' do
    context 'successful submission' do
      before do
        stub_request(:put, %r{localhost:3000/api/validated-forms/v1/[a-f0-9-]+})
          .to_return(status: 200, body: {
            data: {
              id: 'gcio-123',
              attributes: { tracking_number: 'TRACK-456' }
            }
          }.to_json)
      end

      it 'puts to GCIO API' do
        result = service.submit_form_data(payload, uuid)
        expect(result[:status]).to eq(200)
        expect(result[:submission_id]).to eq('gcio-123')
      end

      it 'includes benefits_intake_uuid in headers' do
        service.submit_form_data(payload, uuid)
        expect(WebMock).to have_requested(:put, "localhost:3000/api/validated-forms/v1/#{uuid}")
          .with(headers: { 'X-Benefits-Intake-UUID' => uuid })
      end
    end

    context 'API error' do
      before do
        stub_request(:put, %r{localhost:3000/api/validated-forms/v1/[a-f0-9-]+})
          .to_return(status: 422, body: {
            errors: [{ detail: 'Invalid data' }]
          }.to_json)
      end

      it 'raises ServiceError' do
        expect { service.submit_form_data(payload, uuid) }
          .to raise_error(FormIntake::ServiceError, /Invalid data/)
      end
    end

    context 'timeout' do
      before do
        stub_request(:put, %r{localhost:3000/api/validated-forms/v1/[a-f0-9-]+}).to_raise(Faraday::TimeoutError)
      end

      it 'raises ServiceError with 504' do
        expect { service.submit_form_data(payload, uuid) }
          .to raise_error(FormIntake::ServiceError) do |error|
            expect(error.status_code).to eq(504)
          end
      end
    end
  end
end
