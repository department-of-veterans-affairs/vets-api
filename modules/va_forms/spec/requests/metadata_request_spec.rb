require 'rails_helper'

RSpec.describe 'VA Forms Metadata Endpoint', type: :request do
  describe '#get /metadata' do
    it 'returns metadata JSON' do
      get '/services/va_forms/metadata'
      expect(response).to have_http_status(:ok)
    end
  end

  context 'healthchecks' do
    context 'V0' do
      it 'returns correct response and status when healthy' do
        allow(VaForms::Form).to receive(:count).and_return(1)
        get '/services/va_forms/v0/healthcheck'
        parsed_response = JSON.parse(response.body)
        expect(response.status).to eq(200)
        expect(parsed_response['data']['attributes']['healthy']).to eq(true)
      end

      it 'returns correct status when not healthy' do
        get '/services/va_forms/v0/healthcheck'
        expect(response.status).to eq(503)
      end
    end
  end
end
