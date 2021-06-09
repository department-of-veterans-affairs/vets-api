# frozen_string_literal: true

require 'rails_helper'

describe AppealsApi::Docs::V1::DocsController, type: :request do
  describe '#decision_reviews' do
    before { get '/services/appeals/docs/v1/decision_reviews' }

    let(:json) { JSON.parse(response.body) }

    it 'successfully returns openapi spec' do
      expect(response).to have_http_status(:ok)
      expect(json['openapi']).to eq('3.0.0')
    end

    context 'servers' do
      let(:server_urls) { json['servers'].map { |server| server['url'] } }

      it('lists the sandbox environment') do
        expect(server_urls).to include('https://sandbox-api.va.gov/services/appeals/{version}/decision_reviews')
      end

      it('lists the production environment') do
        expect(server_urls).to include('https://api.va.gov/services/appeals/{version}/decision_reviews')
      end
    end

    it('/higher_level_reviews supports POST') do
      expect(json['paths']['/higher_level_reviews']).to include('post')
    end

    it '/higher_level_reviews/contestable_issues supports GET' do
      expect(json['paths']['/higher_level_reviews/contestable_issues/{benefit_type}']).to include('get')
    end

    it 'HLR statuses match model (if this test fails, has there been a version change?)' do
      expect(json['components']['schemas']['hlrStatus']['enum']).to eq AppealsApi::HigherLevelReview::V1_STATUSES
    end
  end
end
