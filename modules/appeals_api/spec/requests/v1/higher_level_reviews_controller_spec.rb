# frozen_string_literal: true

require 'rails_helper'

describe AppealsApi::V1::DecisionReview::HigherLevelReviewsController, type: :request do
  describe '#index' do
    it 'show a HLR from Caseflow successfully' do
      VCR.use_cassette('appeals/higher_level_reviews_show') do
        get('/services/appeals/v1/decision_review/higher_level_reviews/1234567890')
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['data']).not_to be nil
      end
    end
  end
end
