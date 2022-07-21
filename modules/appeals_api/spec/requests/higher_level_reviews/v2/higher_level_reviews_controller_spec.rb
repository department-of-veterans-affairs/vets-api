# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

describe AppealsApi::HigherLevelReviews::V2::HigherLevelReviewsController, type: :request do
  describe '#schema' do
    let(:path) { '/services/appeals/higher_level_reviews/v2/schemas/200996' }

    it 'renders the json schema' do
      get path
      expect(response.status).to eq(200)

      json_body = JSON.parse response.body
      expect(json_body['description']).to eq('JSON Schema for VA Form 20-0996')
    end
  end
end
