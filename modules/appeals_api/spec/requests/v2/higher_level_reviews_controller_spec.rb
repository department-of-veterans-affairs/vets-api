# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

describe AppealsApi::V2::DecisionReviews::HigherLevelReviewsController, type: :request do
  include FixtureHelpers

  def base_path(path)
    "/services/appeals/v2/decision_reviews/#{path}"
  end

  before(:all) do
    @data = fixture_to_s 'valid_200996_minimum_v2.json'
    @data_extra = fixture_to_s 'valid_200996_extra_v2.json'
    @invalid_data = fixture_to_s 'invalid_200996_v2.json'
    @headers = fixture_as_json 'valid_200996_headers_v2.json'
    @minimum_required_headers = fixture_as_json 'valid_200996_headers_minimum.json'
    @headers_extra = fixture_as_json 'valid_200996_headers_extra_v2.json'
    @invalid_headers = fixture_as_json 'invalid_200996_headers.json'
  end

  let(:parsed) { JSON.parse(response.body) }

  describe '#create' do
    let(:path) { base_path 'higher_level_reviews' }

    context 'with all headers' do
      it 'creates an HLR and persists the data' do
        post(path, params: @data, headers: @headers)
        hlr_guid = JSON.parse(response.body)['data']['id']
        hlr = AppealsApi::HigherLevelReview.find(hlr_guid)
        expect(hlr.source).to eq('va.gov')
        expect(parsed['data']['type']).to eq('higherLevelReview')
        expect(parsed['data']['attributes']['status']).to eq('pending')
      end
    end

    context 'with minimum required headers' do
      it 'creates an HLR and persists the data' do
        post(path, params: @data, headers: @minimum_required_headers)
        expect(parsed['data']['type']).to eq('higherLevelReview')
        expect(parsed['data']['attributes']['status']).to eq('pending')
      end
    end

    context 'with optional claimant headers' do
      it 'creates an HLR and persists the data' do
        post(path, params: @data, headers: @headers_extra)
        expect(parsed['data']['type']).to eq('higherLevelReview')
        expect(parsed['data']['attributes']['status']).to eq('pending')
      end
    end

    context 'when header is missing' do
      it 'responds with status :unprocessable_entity' do
        post(path, params: @data, headers: @minimum_required_headers.except('X-VA-SSN'))
        expect(response.status).to eq(422)
        expect(parsed['errors']).to be_an Array
      end
    end

    context 'when phone number is too long' do
      let(:error_content) do
        { 'status' => 422, 'detail' => 'Phone number will not fit on form (20 char limit): 9991234567890x1234567890' }
      end

      it 'responds with status :unprocessable_entity ' do
        data = JSON.parse(@data)
        data['data']['attributes']['veteran'].merge!(
          { 'phone' => { 'areaCode' => '999', 'phoneNumber' => '1234567890', 'phoneNumberExt' => '1234567890' } }
        )

        post(path, params: data.to_json, headers: @minimum_required_headers)
        expect(response.status).to eq(422)
        expect(parsed['errors']).to include(error_content)
      end

      it 'fails when homeless is false but no address is provided' do
        data = JSON.parse(@data)
        data['data']['attributes']['veteran']['homeless'] = false
        data['data']['attributes']['veteran'].delete('address')

        post(path, params: data.to_json, headers: @minimum_required_headers)
        expect(response.status).to eq(422)

        error = parsed['errors'][0]
        expect(error['title']).to eq 'Missing required fields'
        expect(error['code']).to eq '145'
        expect(error['meta']['missing_fields']).to match_array(['address'])
      end
    end

    it 'create the job to build the PDF' do
      client_stub = instance_double('CentralMail::Service')
      faraday_response = instance_double('Faraday::Response')

      allow(CentralMail::Service).to receive(:new) { client_stub }
      allow(client_stub).to receive(:upload).and_return(faraday_response)
      allow(faraday_response).to receive(:success?).and_return(true)

      Sidekiq::Testing.inline! do
        post(path, params: @data, headers: @headers)
      end

      nod = AppealsApi::HigherLevelReview.find_by(id: parsed['data']['id'])
      expect(nod.status).to eq('submitted')
    end

    context 'when invalid headers supplied' do
      it 'returns an error' do
        post(path, params: @data, headers: @invalid_headers)
        expect(response.status).to eq(422)
        expect(parsed['errors'][0]['detail']).to eq('Veteran birth date isn\'t in the past: 3000-12-31')
      end
    end

    context 'when request.body is a Puma::NullIO' do
      it 'responds with a 422' do
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
    end

    context 'when request.body isn\'t a JSON *object*' do
      before do
        fake_io_object = OpenStruct.new string: json
        allow_any_instance_of(ActionDispatch::Request).to receive(:body).and_return(fake_io_object)
      end

      context 'when request.body is a JSON string' do
        let(:json) { '"Hello!"' }

        it 'responds with a properly formed error object' do
          post(path, params: @data, headers: @headers)
          body = JSON.parse(response.body)
          expect(response.status).to eq 422
          expect(body['errors']).to be_an Array
          expect(body.dig('errors', 0, 'detail')).to eq "The request body isn't a JSON object"
        end
      end

      context 'when request.body is a JSON integer' do
        let(:json) { '66' }

        it 'responds with a properly formed error object' do
          post(path, params: @data, headers: @headers)
          body = JSON.parse(response.body)
          expect(response.status).to eq 422
          expect(body['errors']).to be_an Array
          expect(body.dig('errors', 0, 'detail')).to eq "The request body isn't a JSON object"
        end
      end
    end
  end

  describe '#validate' do
    let(:path) { base_path 'higher_level_reviews/validate' }

    it 'returns a response when minimal data valid' do
      post(path, params: @data, headers: @headers)
      expect(parsed['data']['attributes']['status']).to eq('valid')
      expect(parsed['data']['type']).to eq('higherLevelReviewValidation')
    end

    it 'returns a response when extra data valid' do
      post(path, params: @data_extra, headers: @headers_extra)

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

    it 'allow for status simulation' do
      with_settings(Settings, vsp_environment: 'development') do
        with_settings(Settings.modules_appeals_api, status_simulation_enabled: true) do
          uuid = create(:higher_level_review).id
          status_simulation_headers = { 'Status-Simulation' => 'error' }
          get("#{path}#{uuid}", headers: status_simulation_headers)

          expect(parsed.dig('data', 'attributes', 'status')).to eq('error')
        end
      end
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
