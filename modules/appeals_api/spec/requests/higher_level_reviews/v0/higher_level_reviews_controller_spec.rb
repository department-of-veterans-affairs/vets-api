# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

describe AppealsApi::HigherLevelReviews::V0::HigherLevelReviewsController, type: :request do
  def base_path(path)
    "/services/appeals/higher-level-reviews/v0/#{path}"
  end

  let(:data) { fixture_to_s 'valid_200996_minimum.json', version: 'v2' }
  let(:headers) { fixture_as_json 'valid_200996_headers.json', version: 'v2' }
  let(:headers_extra) { fixture_as_json 'valid_200996_headers_extra.json', version: 'v2' }
  let(:parsed_response) { JSON.parse(response.body) }

  describe '#schema' do
    let(:path) { base_path 'schemas/200996' }

    it 'renders the json schema with shared refs' do
      with_openid_auth(described_class::OAUTH_SCOPES[:GET]) do |auth_header|
        get(path, headers: auth_header)
      end

      expect(response.status).to eq(200)
      expect(parsed_response['description']).to eq('JSON Schema for VA Form 20-0996')
      expect(response.body).to include('{"$ref":"non_blank_string.json"}')
      expect(response.body).to include('{"$ref":"address.json"}')
      expect(response.body).to include('{"$ref":"phone.json"}')
    end

    it_behaves_like('an endpoint with OpenID auth', scopes: described_class::OAUTH_SCOPES[:GET]) do
      def make_request(auth_header)
        get(path, headers: auth_header)
      end
    end
  end

  describe '#create' do
    let(:path) { base_path 'forms/200996' }

    it 'creates an HLR record having api_version: "V0"' do
      with_openid_auth(described_class::OAUTH_SCOPES[:POST]) do |auth_header|
        post(path, params: data, headers: headers.merge(auth_header))
      end

      hlr_guid = JSON.parse(response.body)['data']['id']
      hlr = AppealsApi::HigherLevelReview.find(hlr_guid)

      expect(hlr.api_version).to eq('V0')
    end

    context 'when icn header is not provided' do
      it 'returns a 422 error with details' do
        with_openid_auth(described_class::OAUTH_SCOPES[:POST]) do |auth_header|
          post(path, params: data, headers: headers_extra.except('X-VA-ICN').merge(auth_header))
        end

        expect(response).to have_http_status(:unprocessable_entity)
        expect(parsed_response['errors'][0]['detail']).to include('One or more expected fields were not found')
        expect(parsed_response['errors'][0]['meta']['missing_fields']).to include('X-VA-ICN')
      end
    end
  end

  describe '#validate' do
    let(:path) { base_path 'forms/200996/validate' }

    context 'when icn header is not provided' do
      it 'returns a 422 error with details' do
        with_openid_auth(described_class::OAUTH_SCOPES[:POST]) do |auth_header|
          post(path, params: data, headers: headers_extra.except('X-VA-ICN').merge(auth_header))
        end

        expect(response).to have_http_status(:unprocessable_entity)
        expect(parsed_response['errors'][0]['detail']).to include('One or more expected fields were not found')
        expect(parsed_response['errors'][0]['meta']['missing_fields']).to include('X-VA-ICN')
      end
    end
  end
end
