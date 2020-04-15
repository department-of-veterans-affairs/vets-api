# frozen_string_literal: true

require 'rails_helper'

describe AppealsApi::V1::DecisionReview::HigherLevelReviewsController, type: :request do
  describe '#create' do
    it 'create an HLR and persist the data' do
      body = File.read(Rails.root.join('modules', 'appeals_api', 'spec', 'fixtures', 'valid_200996.json'))
      headers = JSON.parse(
        File.read(
          Rails.root.join('modules', 'appeals_api', 'spec', 'fixtures', 'higher_level_review_create_headers.json')
        )
      )
      post(
        '/services/appeals/v1/decision_review/higher_level_reviews',
        params: body,
        headers: headers
      )
      parsed = JSON.parse(response.body)
      expect(parsed['data']['type']).to eq('higher_level_review')
      expect(parsed['data']['attributes']['status']).to eq('pending')
    end

    it 'create the job to build the PDF' do
      body = File.read(Rails.root.join('modules', 'appeals_api', 'spec', 'fixtures', 'valid_200996.json'))
      headers = JSON.parse(
        File.read(
          Rails.root.join('modules', 'appeals_api', 'spec', 'fixtures', 'higher_level_review_create_headers.json')
        )
      )
      expect do
        post(
          '/services/appeals/v1/decision_review/higher_level_reviews',
          params: body,
          headers: headers
        )
      end .to change(AppealsApi::HigherLevelReviewPdfSubmitJob.jobs, :size).by(1)
    end
  end

  describe '#validate' do
    let(:path) { '/services/appeals_api/v1/decision_review/higher_level_reviews/validate' }

    it 'returns a response when valid' do
      data = File.read(Rails.root.join('modules', 'appeals_api', 'spec', 'fixtures', 'valid_200996.json'))
      post(
        '/services/appeals/v1/decision_review/higher_level_reviews/validate',
        params: data
      )
      parsed = JSON.parse(response.body)
      expect(parsed['data']['attributes']['status']).to eq('valid')
      expect(parsed['data']['type']).to eq('appeals_api_higher_level_review_validation')
    end

    it 'returns a response when invalid' do
      data = File.read(Rails.root.join('modules', 'appeals_api', 'spec', 'fixtures', 'invalid_200996.json'))
      post(
        '/services/appeals/v1/decision_review/higher_level_reviews/validate',
        params: data
      )
      parsed = JSON.parse(response.body)
      expect(response.status).to eq(422)
      expect(parsed['errors']).not_to be_empty
    end

    it 'responds properly when JSON parse error' do
      data = File.read(Rails.root.join('modules', 'appeals_api', 'spec', 'fixtures', 'invalid_200996.json'))
      allow(JSON).to receive(:parse).and_raise(JSON::ParserError)
      post(
        '/services/appeals/v1/decision_review/higher_level_reviews/validate',
        params: data
      )
      expect(response.status).to eq(422)
    end
  end

  describe '#schema' do
    it 'renders the json schema' do
      get '/services/appeals/v1/decision_review/higher_level_reviews/schema'
      expect(response.status).to eq(200)
    end
  end
end
