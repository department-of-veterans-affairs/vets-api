# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

describe AppealsApi::V1::DecisionReviews::HigherLevelReviewsController, type: :request do
  include FixtureHelpers

  def base_path(path)
    "/services/appeals/v1/decision_reviews/#{path}"
  end

  before(:all) do
    @data = fixture_to_s 'valid_200996.json'
    @invalid_data = fixture_to_s 'invalid_200996.json'
    @headers = fixture_as_json 'valid_200996_headers.json'
    @minimum_required_headers = fixture_as_json 'valid_200996_headers_minimum.json'
    @invalid_headers = fixture_as_json 'invalid_200996_headers.json'
  end

  let(:parsed) { JSON.parse(response.body) }

  describe '#create' do
    let(:path) { base_path 'higher_level_reviews' }

    context 'creates an HLR and persists the data' do
      it 'with all headers' do
        post(path, params: @data, headers: @headers)
        expect(parsed['data']['type']).to eq('higherLevelReview')
        expect(parsed['data']['attributes']['status']).to eq('pending')
      end
      it 'with the minimum required headers' do
        post(path, params: @data, headers: @minimum_required_headers)
        expect(parsed['data']['type']).to eq('higherLevelReview')
        expect(parsed['data']['attributes']['status']).to eq('pending')
      end
      it 'fails when a required header is missing' do
        post(path, params: @data, headers: @minimum_required_headers.except('X-VA-SSN'))
        expect(response.status).to eq(422)
        expect(parsed['errors']).to be_an Array
      end
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

    it 'responds with a 422 when request.body is a Puma::NullIO' do
      fake_puma_null_io_object = Object.new.tap do |obj|
        def obj.class
          OpenStruct.new name: 'Puma::NullIO'
        end
      end
      expect(fake_puma_null_io_object.class.name).to eq 'Puma::NullIO'
      allow_any_instance_of(ActionDispatch::Request).to(
        receive(:body).and_return(fake_puma_null_io_object)
      )
      post(path, params: @data, headers: @headers)
      expect(response.status).to eq 422
      expect(JSON.parse(response.body)['errors']).to be_an Array
    end

    context 'responds with a 422 when request.body isn\'t a JSON *object*' do
      before do
        fake_io_object = OpenStruct.new string: json
        allow_any_instance_of(ActionDispatch::Request).to receive(:body).and_return(fake_io_object)
      end

      context 'request.body is a JSON string' do
        let(:json) { '"Hello!"' }

        it 'responds with a properly formed error object' do
          post(path, params: @data, headers: @headers)
          body = JSON.parse(response.body)
          expect(response.status).to eq 422
          expect(body['errors']).to be_an Array
          expect(body.dig('errors', 0, 'detail')).to eq "The request body isn't a JSON object: #{json}"
        end
      end

      context 'request.body is a JSON integer' do
        let(:json) { '66' }

        it 'responds with a properly formed error object' do
          post(path, params: @data, headers: @headers)
          body = JSON.parse(response.body)
          expect(response.status).to eq 422
          expect(body['errors']).to be_an Array
          expect(body.dig('errors', 0, 'detail')).to eq "The request body isn't a JSON object: #{json}"
        end
      end
    end
  end

  describe '#validate' do
    let(:path) { base_path 'higher_level_reviews/validate' }

    it 'returns a response when valid' do
      post(path, params: @data, headers: @headers)
      expect(parsed['data']['attributes']['status']).to eq('valid')
      expect(parsed['data']['type']).to eq('higherLevelReviewValidation')
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

  describe '#show' do
    let(:path) { base_path 'higher_level_reviews/' }

    it 'returns a higher_level_review with all of its data' do
      uuid = create(:higher_level_review).id
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
