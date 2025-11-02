# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::Form21p530aController, type: :controller do
  let(:valid_payload) { JSON.parse(Rails.root.join('spec', 'fixtures', 'form21p530a', 'valid_form.json').read) }

  describe 'POST #create' do
    it 'returns expected response structure' do
      post(:create, body: valid_payload.to_json, as: :json)

      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body)
      expect(json['data']['type']).to eq('saved_claims')
      expect(json['data']['attributes']['form']).to eq('21P-530A')
      expect(json['data']['attributes']['confirmation_number']).to be_present
      expect(json['data']['attributes']['submitted_at']).to be_present
      expect(json['data']['attributes']['guid']).to be_present
      expect(json['data']['attributes']['regional_office']).to be_an(Array)
    end

    it 'returns a unique confirmation number for each request' do
      post(:create, body: valid_payload.to_json, as: :json)
      first_confirmation = JSON.parse(response.body)['data']['attributes']['confirmation_number']

      post(:create, body: valid_payload.to_json, as: :json)
      second_confirmation = JSON.parse(response.body)['data']['attributes']['confirmation_number']

      expect(first_confirmation).not_to eq(second_confirmation)
    end

    it 'returns a valid UUID as confirmation number' do
      post(:create, body: valid_payload.to_json, as: :json)

      confirmation = JSON.parse(response.body).dig('data', 'attributes', 'confirmation_number')
      expect(confirmation).to be_a_uuid
    end

    it 'returns ISO 8601 formatted timestamp' do
      post(:create, body: valid_payload.to_json, as: :json)

      submitted_at = JSON.parse(response.body).dig('data', 'attributes', 'submitted_at')
      expect { DateTime.iso8601(submitted_at) }.not_to raise_error
    end

    it 'does not require authentication' do
      post(:create, body: valid_payload.to_json, as: :json)
      expect(response).to have_http_status(:ok)
    end

    it 'queues Lighthouse submission job' do
      expect(Lighthouse::SubmitBenefitsIntakeClaim).to receive(:perform_async).with(anything)
      post(:create, body: valid_payload.to_json, as: :json)
    end

    context 'with invalid form data' do
      let(:invalid_payload) do
        {
          veteranInformation: {
            fullName: { first: 'OnlyFirst' }
          }
        }
      end

      it 'returns validation errors' do
        post(:create, body: invalid_payload.to_json, as: :json)

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['errors']).to be_present
      end

      it 'increments failure stats' do
        expect(StatsD).to receive(:increment).with('api.form21p530a.failure')
        post(:create, body: invalid_payload.to_json, as: :json)
      end
    end
  end

  describe 'POST #download_pdf' do
    it 'returns stub response indicating not yet implemented' do
      post(:download_pdf, body: valid_payload.to_json, as: :json)

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['message']).to eq('PDF download not yet implemented')
    end

    it 'does not require authentication' do
      post(:download_pdf, body: valid_payload.to_json, as: :json)

      expect(response).to have_http_status(:ok)
    end
  end
end
