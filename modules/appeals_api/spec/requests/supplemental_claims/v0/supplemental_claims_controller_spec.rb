# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

describe AppealsApi::SupplementalClaims::V0::SupplementalClaimsController, type: :request do
  let(:parsed_response) { JSON.parse(response.body) }
  let(:default_data) { fixture_as_json 'supplemental_claims/v0/valid_200995_extra.json' }

  def base_path(path)
    "/services/appeals/supplemental-claims/v0/#{path}"
  end

  describe '#index', skip: 'Waiting for v0 release' do
    let(:path) { base_path 'forms/200995' }
    let(:veteran_icn) { '1013062086V794840' }
    let!(:supplemental_claim1) { create(:supplemental_claim_v0, veteran_icn:) }
    let!(:supplemental_claim2) { create(:supplemental_claim_v0, veteran_icn:) }
    let!(:other_supplemental_claim) do
      other_icn = '1111111111V111111'
      sc = create(:extra_supplemental_claim_v0, veteran_icn: other_icn)
      sc.form_data['data']['attributes']['veteran']['icn'] = other_icn
      sc.save
      sc
    end
    let(:params) { { icn: veteran_icn } }

    describe 'responses' do
      before do
        with_openid_auth(described_class::OAUTH_SCOPES[:GET]) do |auth_header|
          get(path, params:, headers: auth_header)
        end
      end

      context 'when given a valid ICN parameter' do
        let(:params) { { icn: veteran_icn } }

        it 'returns a list of supplemental claims associated with the given ICN' do
          expect(parsed_response['data'].pluck('id'))
            .to match_array([supplemental_claim1.id, supplemental_claim2.id])
        end
      end

      context 'when given an invalid ICN parameter' do
        let(:params) { { icn: 'not-an-icn' } }

        it 'returns a 422 error' do
          expect(response).to have_http_status(:unprocessable_entity)
        end
      end

      context 'when the ICN parameter is missing' do
        let(:params) { {} }

        it 'returns a 422 error' do
          expect(response).to have_http_status(:unprocessable_entity)
        end
      end
    end

    describe 'auth behavior' do
      it_behaves_like('an endpoint with OpenID auth', scopes: described_class::OAUTH_SCOPES[:GET]) do
        def make_request(auth_header)
          get(path, headers: auth_header, params: { icn: veteran_icn })
        end
      end
    end
  end

  describe '#schema' do
    let(:path) { base_path 'schemas/200995' }

    it 'renders the json schema with shared refs' do
      with_openid_auth(described_class::OAUTH_SCOPES[:GET]) do |auth_header|
        get(path, headers: auth_header)
      end

      expect(response.status).to eq(200)
      expect(parsed_response['description']).to eq('JSON Schema for VA Form 20-0995')
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
    let(:uuid) { create(:supplemental_claim_v0).id }
    let(:path) { base_path "forms/200995/#{uuid}" }

    it_behaves_like('an endpoint with OpenID auth', scopes: described_class::OAUTH_SCOPES[:GET]) do
      def make_request(auth_header)
        get(path, headers: auth_header)
      end
    end
  end

  describe '#create' do
    let(:path) { base_path 'forms/200995' }
    let(:data) { default_data }
    let(:headers) { fixture_as_json 'supplemental_claims/v0/valid_200995_headers.json' }

    describe 'auth behavior' do
      it_behaves_like('an endpoint with OpenID auth', scopes: described_class::OAUTH_SCOPES[:POST]) do
        def make_request(auth_header)
          post(path, params: default_data.to_json, headers: headers.merge(auth_header))
        end
      end
    end

    describe 'responses' do
      let(:json_body) { JSON.parse(response.body) }

      before do
        with_openid_auth(described_class::OAUTH_SCOPES[:POST]) do |auth_header|
          post(path, params: data.to_json, headers: headers.merge(auth_header))
        end
      end

      it 'creates an SC record having api_version: "V0"' do
        created_record = AppealsApi::SupplementalClaim.find(json_body['data']['id'])

        expect(created_record.api_version).to eq('V0')
      end

      context 'when icn is not provided' do
        let(:data) do
          default_data['data']['attributes']['veteran'].delete('icn')
          default_data
        end

        it 'returns a 422 error' do
          expect(response).to have_http_status(:unprocessable_entity)
          expect(parsed_response['errors'][0]['detail']).to include('One or more expected fields were not found')
          expect(parsed_response['errors'][0]['source']['pointer']).to eq('/data/attributes/veteran')
          expect(parsed_response['errors'][0]['meta']['missing_fields']).to include('icn')
        end
      end

      context 'when veteran birth date is not in the past' do
        let(:data) do
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
        let(:data) do
          default_data['data']['attributes']['claimant']['birthDate'] = DateTime.tomorrow.strftime('%F')
          default_data
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
    let(:path) { base_path 'forms/200995/validate' }
    let(:data) { default_data }
    let(:headers) { fixture_as_json 'supplemental_claims/v0/valid_200995_headers.json' }

    it_behaves_like('an endpoint with OpenID auth', scopes: described_class::OAUTH_SCOPES[:POST]) do
      def make_request(auth_header)
        post(path, params: data.to_json, headers: headers.merge(auth_header))
      end
    end

    context 'when veteran icn is not provided' do
      before do
        with_openid_auth(described_class::OAUTH_SCOPES[:POST]) do |auth_header|
          data['data']['attributes']['veteran'].delete('icn')
          post(path, params: data.to_json, headers: headers.merge(auth_header))
        end
      end

      it 'returns a 422 error with details' do
        expect(response).to have_http_status(:unprocessable_entity)
        expect(parsed_response['errors'][0]['detail']).to include('One or more expected fields were not found')
        expect(parsed_response['errors'][0]['source']['pointer']).to eq('/data/attributes/veteran')
        expect(parsed_response['errors'][0]['meta']['missing_fields']).to include('icn')
      end
    end
  end

  describe '#download', skip: 'Waiting for v0 release' do
    it_behaves_like 'watermarked pdf download endpoint', { factory: :supplemental_claim_v0 }
  end
end
