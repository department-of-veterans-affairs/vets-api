# frozen_string_literal: true

require 'rails_helper'

describe AppealsApi::V1::DecisionReview::HigherLevelReviewsController, type: :request do
  describe '#show' do
    it 'show a HLR from Caseflow successfully' do
      VCR.use_cassette('appeals/higher_level_reviews_show') do
        get('/services/appeals/v1/decision_review/higher_level_reviews/97bca3d5-3524-4e5d-81ea-92753892a59c')
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['data']).not_to be nil
      end
    end
  end

  describe '#create' do
    it 'create an HLR through Caseflow successfully' do
      data = File.read(Rails.root.join('modules', 'appeals_api', 'spec', 'fixtures', 'valid_200996.json'))
      post(
        '/services/appeals/v1/decision_review/higher_level_reviews/validate',
        params: data)
      parsed = JSON.parse(response.body)
      expect(parsed['data']['attributes']['status']).to eq('valid')
      expect(parsed['data']['type']).to eq('appeals_api_higher_level_review_validation')
    end
  end

  describe '#validate' do
    let(:path) { '/services/appeals_api/v1/decision_review/higher_level_reviews/validate' }

    it 'returns a response when valid' do
      data = File.read(Rails.root.join('modules', 'appeals_api', 'spec', 'fixtures', 'valid_200996.json'))
      post(
        '/services/appeals/v1/decision_review/higher_level_reviews',
        params: data)
      parsed = JSON.parse(response.body)
      expect(parsed['data']['success']).to eq(true)
    end

    it 'returns a response when invalid' do
      data = File.read(Rails.root.join('modules', 'appeals_api', 'spec', 'fixtures', 'invalid_200996.json'))
      post(
        '/services/appeals/v1/decision_review/higher_level_reviews/validate',
        params: data)
      parsed = JSON.parse(response.body)
      expect(response.status).to eq(422)
      expect(parsed['errors'].size).to eq(3)
    end
  end
end