# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

describe AppealsApi::HigherLevelReviews::V0::HigherLevelReviewsController, type: :request do
  def base_path(path)
    "/services/appeals/higher-level-reviews/v0/#{path}"
  end

  let(:default_headers) { fixture_as_json 'higher_level_reviews/v0/valid_200996_headers.json' }
  let(:default_data) { fixture_as_json 'higher_level_reviews/v0/valid_200996.json' }
  let(:min_data) { fixture_as_json 'higher_level_reviews/v0/valid_200996_minimum.json' }
  let(:max_data) { fixture_as_json 'higher_level_reviews/v0/valid_200996_extra.json' }
  let(:parsed_response) { JSON.parse(response.body) }

  describe '#schema' do
    let(:path) { base_path 'schemas/200996' }

    it 'renders the json schema with shared refs' do
      with_openid_auth(described_class::OAUTH_SCOPES[:GET]) do |auth_header|
        get(path, headers: auth_header)
      end

      expect(response.status).to eq(200)
      expect(parsed_response['description']).to eq('JSON Schema for VA Form 20-0996')
      expect(response.body).to include('{"$ref":"nonBlankString.json"}')
      expect(response.body).to include('{"$ref":"address.json"}')
      expect(response.body).to include('{"$ref":"phone.json"}')
    end

    it_behaves_like('an endpoint with OpenID auth', scopes: described_class::OAUTH_SCOPES[:GET]) do
      def make_request(auth_header)
        get(path, headers: auth_header)
      end
    end
  end

  describe '#show' do
    let(:id) { create(:higher_level_review_v0).id }
    let(:path) { base_path "forms/200996/#{id}" }

    describe 'auth behavior' do
      it_behaves_like('an endpoint with OpenID auth', scopes: described_class::OAUTH_SCOPES[:GET]) do
        def make_request(auth_header)
          get(path, headers: auth_header)
        end
      end
    end

    describe 'responses' do
      before do
        with_openid_auth(described_class::OAUTH_SCOPES[:GET]) { |auth_header| get(path, headers: auth_header) }
      end

      it 'returns only the data from the ALLOWED_COLUMNS' do
        expect(parsed_response.dig('data', 'attributes').keys).to eq(%w[status updatedAt createdAt])
      end
    end
  end

  describe '#create' do
    let(:path) { base_path 'forms/200996' }
    let(:params) { default_data }
    let(:headers) { default_headers }

    describe 'auth behavior' do
      it_behaves_like 'an endpoint with OpenID auth', scopes: described_class::OAUTH_SCOPES[:POST] do
        def make_request(auth_header)
          post(path, params: params.to_json, headers: headers.merge(auth_header))
        end
      end
    end

    describe 'responses' do
      before do
        with_openid_auth(described_class::OAUTH_SCOPES[:POST]) do |auth_header|
          post(path, params: params.to_json, headers: headers.merge(auth_header))
        end
      end

      it 'creates an HLR record having api_version: "V0"' do
        expect(response).to have_http_status(:ok)

        hlr = AppealsApi::HigherLevelReview.find(parsed_response['data']['id'])

        expect(hlr.api_version).to eq('V0')
      end

      context 'when body does not match schema' do
        let(:params) do
          default_data['data']['attributes']['veteran'].delete('icn')
          default_data['data']['attributes']['veteran'].delete('firstName')
          default_data
        end

        it 'returns a 422 error with details' do
          expect(response).to have_http_status(:unprocessable_entity)
          expect(parsed_response['errors'][0]['detail']).to include('One or more expected fields were not found')
          expect(parsed_response['errors'][0]['meta']['missing_fields']).to include('icn', 'firstName')
        end
      end

      context 'when veteran birth date is not in the past' do
        let(:params) do
          default_data['data']['attributes']['veteran']['birthDate'] = DateTime.tomorrow.strftime('%F')
          default_data
        end

        it 'returns a 422 error' do
          expect(response).to have_http_status(:unprocessable_entity)
          expect(parsed_response['errors'][0]['detail']).to include('Date must be in the past')
          expect(parsed_response['errors'][0]['source']['pointer']).to eq('/data/attributes/veteran/birthDate')
        end
      end

      context 'when claimant birth date is not in the past' do
        let(:params) do
          max_data['data']['attributes']['claimant']['birthDate'] = DateTime.tomorrow.strftime('%F')
          max_data
        end

        it 'returns a 422 error' do
          expect(response).to have_http_status(:unprocessable_entity)
          expect(parsed_response['errors'][0]['detail']).to include('Date must be in the past')
          expect(parsed_response['errors'][0]['source']['pointer']).to eq('/data/attributes/claimant/birthDate')
        end
      end
    end
  end

  describe '#validate' do
    let(:path) { base_path 'forms/200996/validate' }
    let(:headers) { default_headers }

    context 'when icn header is not provided' do
      let(:params) do
        default_data['data']['attributes']['veteran'].delete('icn')
        default_data.to_json
      end

      it 'returns a 422 error with details' do
        with_openid_auth(described_class::OAUTH_SCOPES[:POST]) do |auth_header|
          post(path, params:, headers: headers.merge(auth_header))
        end

        expect(response).to have_http_status(:unprocessable_entity)
        expect(parsed_response['errors'][0]['detail']).to include('One or more expected fields were not found')
        expect(parsed_response['errors'][0]['meta']['missing_fields']).to include('icn')
      end
    end

    it_behaves_like 'an endpoint with OpenID auth', scopes: described_class::OAUTH_SCOPES[:POST] do
      def make_request(auth_header)
        post(path, params: default_data.to_json, headers: headers.merge(auth_header))
      end
    end
  end

  describe '#download' do
    it_behaves_like 'watermarked pdf download endpoint', { factory: :higher_level_review_v0 }
  end
end
