# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::Form214192Controller, type: :controller do
  describe 'POST #create' do
    it 'returns expected response structure' do
      form_data = {
        veteranInformation: { fullName: { first: 'John', last: 'Doe' } },
        employerInformation: { employerName: 'Acme Corp' }
      }

      post(:create, params: { form214192: form_data })

      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body)
      expect(json['data']['type']).to eq('saved_claims')
      expect(json['data']['attributes']['form']).to eq('21-4192')
      expect(json['data']['attributes']['confirmation_number']).to be_present
      expect(json['data']['attributes']['submitted_at']).to be_present
      expect(json['data']['attributes']['guid']).to be_present
      expect(json['data']['attributes']['regional_office']).to eq([])
    end

    it 'returns a unique confirmation number for each request' do
      form_data = {
        veteranInformation: { fullName: { first: 'John', last: 'Doe' } },
        employerInformation: { employerName: 'Acme Corp' }
      }

      post(:create, params: { form214192: form_data })
      first_confirmation = JSON.parse(response.body)['data']['attributes']['confirmation_number']

      post(:create, params: { form214192: form_data })
      second_confirmation = JSON.parse(response.body)['data']['attributes']['confirmation_number']

      expect(first_confirmation).not_to eq(second_confirmation)
    end

    it 'returns a valid UUID as confirmation number' do
      form_data = {
        veteranInformation: { fullName: { first: 'John', last: 'Doe' } },
        employerInformation: { employerName: 'Acme Corp' }
      }

      post(:create, params: { form214192: form_data })

      json = JSON.parse(response.body)
      confirmation = json['data']['attributes']['confirmation_number']

      expect(confirmation).to be_a_uuid
    end

    it 'returns ISO 8601 formatted timestamp' do
      form_data = {
        veteranInformation: { fullName: { first: 'John', last: 'Doe' } },
        employerInformation: { employerName: 'Acme Corp' }
      }

      post(:create, params: { form214192: form_data })

      json = JSON.parse(response.body)
      submitted_at = json['data']['attributes']['submitted_at']

      expect { DateTime.iso8601(submitted_at) }.not_to raise_error
    end

    it 'does not require authentication' do
      form_data = {
        veteranInformation: { fullName: { first: 'John', last: 'Doe' } },
        employerInformation: { employerName: 'Acme Corp' }
      }

      # Post without signing in
      post(:create, params: { form214192: form_data })

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'POST #download_pdf' do
    it 'returns stub message' do
      post(:download_pdf, params: { form: '{}' })

      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body)
      expect(json['message']).to eq('PDF download stub - not yet implemented')
    end

    it 'does not require authentication' do
      post(:download_pdf, params: { form: '{}' })

      expect(response).to have_http_status(:ok)
    end
  end
end
