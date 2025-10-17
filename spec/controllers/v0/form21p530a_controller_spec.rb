# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::Form21p530aController, type: :controller do
  describe 'POST #create' do
    it 'returns expected response structure' do
      form_data = {
        veteranFullName: { first: 'John', last: 'Doe' },
        veteranSocialSecurityNumber: '123456789',
        deathDate: '2023-12-01',
        cemeteryOrganizationName: 'Illinois Department of Veterans Affairs'
      }

      post(:create, params: { form21p530a: form_data })

      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body)
      expect(json['data']['type']).to eq('saved_claims')
      expect(json['data']['attributes']['form']).to eq('21P-530a')
      expect(json['data']['attributes']['confirmation_number']).to be_present
      expect(json['data']['attributes']['submitted_at']).to be_present
      expect(json['data']['attributes']['guid']).to be_present
      expect(json['data']['attributes']['regional_office']).to include('Pension Management Center')
    end

    it 'returns a unique confirmation number for each request' do
      form_data = {
        veteranFullName: { first: 'John', last: 'Doe' },
        cemeteryOrganizationName: 'Illinois Department of Veterans Affairs'
      }

      post(:create, params: { form21p530a: form_data })
      first_confirmation = JSON.parse(response.body)['data']['attributes']['confirmation_number']

      post(:create, params: { form21p530a: form_data })
      second_confirmation = JSON.parse(response.body)['data']['attributes']['confirmation_number']

      expect(first_confirmation).not_to eq(second_confirmation)
    end

    it 'returns a valid UUID as confirmation number' do
      form_data = {
        veteranFullName: { first: 'John', last: 'Doe' },
        cemeteryOrganizationName: 'Illinois Department of Veterans Affairs'
      }

      post(:create, params: { form21p530a: form_data })

      json = JSON.parse(response.body)
      confirmation = json['data']['attributes']['confirmation_number']

      expect(confirmation).to be_a_uuid
    end

    it 'returns ISO 8601 formatted timestamp' do
      form_data = {
        veteranFullName: { first: 'John', last: 'Doe' },
        cemeteryOrganizationName: 'Illinois Department of Veterans Affairs'
      }

      post(:create, params: { form21p530a: form_data })

      json = JSON.parse(response.body)
      submitted_at = json['data']['attributes']['submitted_at']

      expect { DateTime.iso8601(submitted_at) }.not_to raise_error
    end

    it 'does not require authentication' do
      form_data = {
        veteranFullName: { first: 'John', last: 'Doe' },
        cemeteryOrganizationName: 'Illinois Department of Veterans Affairs'
      }

      # Post without signing in
      post(:create, params: { form21p530a: form_data })

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'GET #download_pdf' do
    it 'returns stub message' do
      get(:download_pdf, params: { form: '{}' })

      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body)
      expect(json['message']).to eq('PDF download stub - not yet implemented')
    end

    it 'does not require authentication' do
      get(:download_pdf, params: { form: '{}' })

      expect(response).to have_http_status(:ok)
    end
  end
end
