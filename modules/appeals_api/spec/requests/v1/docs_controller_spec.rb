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

    it('/higher_level_reviews supports POST') do
      expect(json['paths']['/higher_level_reviews']).to include('post')
    end

    it '/contestable_issues supports GET' do
      expect(json['paths']['/contestable_issues']).to include('get')
    end

    it 'HLR statuses match model (if this test fails, has there been a version change?)' do
      expect(json['components']['schemas']['hlrStatus']['enum']).to eq AppealsApi::HigherLevelReview::STATUSES
    end
  end
end
