# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

describe AppealsApi::V1::DecisionReviews::NoticeOfDisagreementsController, type: :request do
  include FixtureHelpers

  def base_path(path)
    "/services/appeals/v1/decision_reviews/#{path}"
  end

  before(:all) do
    @data = fixture_to_s 'valid_10182.json'
    @invalid_data = fixture_to_s 'invalid_10182.json'
    @headers = fixture_as_json 'valid_10182_headers.json'
    @minimum_required_headers = fixture_as_json 'valid_10182_headers_minimum.json'
  end

  let(:parsed) { JSON.parse(response.body) }

  describe '#validate' do
    let(:path) { base_path 'notice_of_disagreements/validate' }

    context 'when validation passes' do
      it 'returns a valid response' do
        post(path, params: @data, headers: @headers)
        expect(parsed['data']['attributes']['status']).to eq('valid')
        expect(parsed['data']['type']).to eq('noticeOfDisagreementValidation')
      end
    end

    context 'when validation fails due to invalid data' do
      it 'returns an error response' do
        post(path, params: @invalid_data, headers: @headers)
        expect(response.status).to eq(422)
        expect(parsed['errors']).not_to be_empty
      end
    end

    context 'when validation fails due to a JSON parse error' do
      it 'responds with a JSON parse error' do
        allow(JSON).to receive(:parse).and_raise(JSON::ParserError)
        post(path, params: @data, headers: @headers)
        expect(response.status).to eq(422)
      end
    end
  end

  describe '#schema' do
    let(:path) { base_path 'notice_of_disagreements/schema' }

    it 'renders the json schema' do
      get path
      expect(response.status).to eq(200)
    end
  end
end
