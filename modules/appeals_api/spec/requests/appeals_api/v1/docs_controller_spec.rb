# frozen_string_literal: true

require 'rails_helper'

Rspec.describe 'AppealsApi::V1::Docs', type: :request do
  describe '#decision_reviews' do
    before { get '/services/appeals/docs/v1/decision_reviews' }

    let(:json) { JSON.parse(response.body) }

    it 'successfully returns openapi spec' do
      expect(response).to have_http_status(:ok)
      expect(json['openapi']).to eq('3.0.0')
    end

    context 'servers' do
      let(:server_urls) { json['servers'].pluck('url') }

      it('lists the sandbox environment') do
        expect(server_urls).to include('https://sandbox-api.va.gov/services/appeals/{version}/decision_reviews')
      end

      it('lists the production environment') do
        expect(server_urls).to include('https://api.va.gov/services/appeals/{version}/decision_reviews')
      end
    end
  end
end
