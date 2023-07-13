# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

describe AppealsApi::NoticeOfDisagreements::V0::NoticeOfDisagreementsController, type: :request do
  def base_path(path)
    "/services/appeals/notice-of-disagreements/v0/#{path}"
  end

  let(:minimum_data) { fixture_to_s 'notice_of_disagreements/v0/valid_10182_minimum.json' }
  let(:max_data) { fixture_to_s 'notice_of_disagreements/v0/valid_10182_extra.json' }
  let(:max_headers) { fixture_as_json 'notice_of_disagreements/v0/valid_10182_headers_extra.json' }
  let(:parsed_response) { JSON.parse(response.body) }

  describe '#schema' do
    let(:path) { base_path 'schemas/10182' }

    it 'renders the json schema with shared refs' do
      with_openid_auth(described_class::OAUTH_SCOPES[:GET]) do |auth_header|
        get(path, headers: auth_header)
      end

      expect(response.status).to eq(200)
      expect(parsed_response['description']).to eq('JSON Schema for VA Form 10182')
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
    let(:path) { base_path 'forms/10182' }

    it_behaves_like('an endpoint with OpenID auth', scopes: described_class::OAUTH_SCOPES[:POST]) do
      def make_request(auth_header) = post(path, params: max_data, headers: max_headers.merge(auth_header))
    end

    it 'creates an NOD record having api_version: "V0"' do
      with_openid_auth(described_class::OAUTH_SCOPES[:POST]) do |auth_header|
        post(path, params: max_data, headers: max_headers.merge(auth_header))
      end

      expect(response).to have_http_status(:ok)

      nod_guid = JSON.parse(response.body)['data']['id']
      nod = AppealsApi::NoticeOfDisagreement.find(nod_guid)

      expect(nod.api_version).to eq('V0')
    end

    context 'when icn header is not provided' do
      it 'returns a 422 error with details' do
        with_openid_auth(described_class::OAUTH_SCOPES[:POST]) do |auth_header|
          post(path, params: minimum_data, headers: max_headers.except('X-VA-ICN').merge(auth_header))
        end

        expect(response).to have_http_status(:unprocessable_entity)
        expect(parsed_response['errors'][0]['detail']).to include('One or more expected fields were not found')
        expect(parsed_response['errors'][0]['meta']['missing_fields']).to include('X-VA-ICN')
      end
    end
  end

  describe '#show' do
    let(:uuid) { create(:notice_of_disagreement_v0).id }
    let(:path) { base_path "forms/10182/#{uuid}" }

    it_behaves_like('an endpoint with OpenID auth', scopes: described_class::OAUTH_SCOPES[:GET]) do
      def make_request(auth_header) = get(path, headers: auth_header)
    end
  end

  describe '#validate' do
    let(:path) { base_path 'forms/10182/validate' }

    it_behaves_like('an endpoint with OpenID auth', scopes: described_class::OAUTH_SCOPES[:POST]) do
      def make_request(auth_header) = post(path, params: max_data, headers: max_headers.merge(auth_header))
    end

    context 'when icn header is not provided' do
      it 'returns a 422 error with details' do
        with_openid_auth(described_class::OAUTH_SCOPES[:POST]) do |auth_header|
          post(path, params: minimum_data, headers: max_headers.except('X-VA-ICN').merge(auth_header))
        end

        expect(response).to have_http_status(:unprocessable_entity)
        expect(parsed_response['errors'][0]['detail']).to include('One or more expected fields were not found')
        expect(parsed_response['errors'][0]['meta']['missing_fields']).to include('X-VA-ICN')
      end
    end
  end

  describe '#download' do
    it_behaves_like 'watermarked pdf download endpoint', {
      expunged_attrs: { board_review_option: 'hearing' },
      factory: :notice_of_disagreement_v0
    }
  end
end
