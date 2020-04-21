# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

describe AppealsApi::V1::DecisionReview::HigherLevelReviewsController, type: :request do
  include FixtureHelpers

  def base_path(path)
    "/services/appeals/v1/decision_review/#{path}"
  end

  before(:all) do
    @data = fixture_to_s 'valid_200996.json'
    @invalid_data = fixture_to_s 'invalid_200996.json'
    @headers = fixture_as_json 'valid_200996_headers.json'
    @invalid_headers = fixture_as_json 'invalid_200996_headers.json'
  end

  let(:parsed) { JSON.parse(response.body) }

  describe '#create' do
    let(:path) { base_path 'higher_level_reviews' }

    it 'create an HLR and persist the data' do
      post(path, params: @data, headers: @headers)
      expect(parsed['data']['type']).to eq('higher_level_review')
      expect(parsed['data']['attributes']['status']).to eq('pending')
    end

    it 'create the job to build the PDF' do
      expect { post(path, params: @data, headers: @headers) }.to(
        change(AppealsApi::HigherLevelReviewPdfSubmitJob.jobs, :size).by(1)
      )
    end

    it 'invalid headers return an error' do
      post(path, params: @data, headers: @invalid_headers)
      expect(response.status).to eq(422)
      expect(parsed['errors'][0]['detail']).to eq('Veteran birth date isn\'t in the past: 3000-12-31')
    end
  end

  describe '#validate' do
    let(:path) { base_path 'higher_level_reviews/validate' }

    it 'returns a response when valid' do
      post(path, params: @data, headers: @headers)
      expect(parsed['data']['attributes']['status']).to eq('valid')
      expect(parsed['data']['type']).to eq('appeals_api_higher_level_review_validation')
    end

    it 'returns a response when invalid' do
      post(path, params: @invalid_data, headers: @headers)
      expect(response.status).to eq(422)
      expect(parsed['errors']).not_to be_empty
    end

    it 'responds properly when JSON parse error' do
      allow(JSON).to receive(:parse).and_raise(JSON::ParserError)
      post(path, params: @invalid_data, headers: @headers)
      expect(response.status).to eq(422)
    end
  end

  describe '#schema' do
    let(:path) { base_path 'higher_level_reviews/schema' }

    it 'renders the json schema' do
      get path
      expect(response.status).to eq(200)
    end
  end
end
