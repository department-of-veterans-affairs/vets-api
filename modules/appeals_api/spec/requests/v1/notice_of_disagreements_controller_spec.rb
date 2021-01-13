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
    @minimum_valid_data = fixture_to_s 'valid_10182_minimum.json'
    @invalid_data = fixture_to_s 'invalid_10182.json'
    @headers = fixture_as_json 'valid_10182_headers.json'
    @minimum_required_headers = fixture_as_json 'valid_10182_headers_minimum.json'
  end

  let(:parsed) { JSON.parse(response.body) }

  describe '#create' do
    let(:path) { base_path 'notice_of_disagreements' }

    context 'creates an NOD and persists the data' do
      it 'with all headers' do
        post(path, params: @data, headers: @headers)
        expect(parsed['data']['type']).to eq('noticeOfDisagreement')
        expect(parsed['data']['attributes']['status']).to eq('pending')
      end

      it 'with the minimum required headers' do
        post(path, params: @minimum_valid_data, headers: @minimum_required_headers)
        expect(parsed['data']['type']).to eq('noticeOfDisagreement')
      end

      it 'fails when a required header is missing' do
        post(path, params: @data, headers: @minimum_required_headers.except('X-VA-Veteran-SSN'))
        expect(response.status).to eq(422)
        expect(parsed['errors']).to be_an Array
      end
    end

    it 'create the job to build the PDF' do
      expect { post(path, params: @data, headers: @headers) }.to(
        change(AppealsApi::NoticeOfDisagreementPdfSubmitJob.jobs, :size).by(1)
      )
    end
  end

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
      before { post(path, params: @invalid_data, headers: @headers) }

      it 'returns an error response' do
        expect(response.status).to eq(422)
        expect(parsed['errors']).not_to be_empty
      end

      it 'returns error objects in JSON API 1.0 ErrorObject format' do
        expected_keys = %w[code detail links meta sentry_type source status title]
        expect(parsed['errors'].first.keys).to match_array(expected_keys)
        expect(parsed['errors'][0]['source']['pointer']).to eq '/data/attributes/hearingTypePreference'
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

  describe '#show' do
    let(:path) { base_path 'notice_of_disagreements/' }

    it 'returns a notice_of_disagreement with all of its data' do
      uuid = create(:notice_of_disagreement).id
      get("#{path}#{uuid}")
      expect(response.status).to eq(200)
      expect(parsed.dig('data', 'attributes', 'formData')).to be_a Hash
    end

    it 'returns an error when given a bad uuid' do
      uuid = 0
      get("#{path}#{uuid}")
      expect(response.status).to eq(404)
      expect(parsed['errors']).to be_an Array
      expect(parsed['errors']).not_to be_empty
    end
  end
end
