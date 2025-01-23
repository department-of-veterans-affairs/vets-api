# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

Rspec.describe 'AppealsApi::SupplementalClaims::V0::Forms::200995', type: :request do
  let(:parsed_response) { JSON.parse(response.body) }
  let(:default_data) { fixture_as_json 'supplemental_claims/v0/valid_200995_extra.json' }
  let(:other_icn) { '1234567890V987654' }

  def base_path(path)
    "/services/appeals/supplemental-claims/v0/#{path}"
  end

  describe '#schema' do
    let(:path) { base_path 'schemas/200995' }

    it 'renders the json schema with shared refs' do
      with_openid_auth(
        AppealsApi::SupplementalClaims::V0::SupplementalClaimsController::OAUTH_SCOPES[:GET]
      ) do |auth_header|
        get(path, headers: auth_header)
      end

      expect(response).to have_http_status(:ok)
      expect(parsed_response['description']).to eq('JSON Schema for VA Form 20-0995')
      expect(response.body).to include('{"$ref":"address.json"}')
      expect(response.body).to include('{"$ref":"phone.json"}')
    end

    it_behaves_like('an endpoint with OpenID auth',
                    scopes: AppealsApi::SupplementalClaims::V0::SupplementalClaimsController::OAUTH_SCOPES[:GET]) do
      def make_request(auth_header)
        get(path, headers: auth_header)
      end
    end
  end

  describe '#show' do
    let(:id) { create(:supplemental_claim_v0).id }
    let(:path) { base_path "forms/200995/#{id}" }

    describe 'auth behavior' do
      it_behaves_like('an endpoint with OpenID auth',
                      scopes: AppealsApi::SupplementalClaims::V0::SupplementalClaimsController::OAUTH_SCOPES[:GET]) do
        def make_request(auth_header)
          get(path, headers: auth_header)
        end
      end
    end

    describe 'responses' do
      let(:body) { JSON.parse(response.body) }
      let(:scopes) { %w[veteran/SupplementalClaims.read] }

      before do
        with_openid_auth(scopes) do |auth_header|
          get(path, headers: auth_header)
        end
      end

      it 'returns only minimal data with no PII' do
        expect(body.dig('data', 'attributes').keys).to eq(%w[status createDate updateDate])
      end

      context "with a veteran token where the token's ICN doesn't match the appeal's recorded ICN" do
        let(:id) { create(:supplemental_claim_v0, veteran_icn: other_icn).id }

        it 'returns a 403 Forbidden error' do
          expect(response).to have_http_status(:forbidden)
        end
      end
    end
  end

  describe '#create' do
    let(:path) { base_path 'forms/200995' }
    let(:data) { default_data }
    let(:params) { data.to_json }
    let(:headers) { fixture_as_json 'supplemental_claims/v0/valid_200995_headers.json' }

    describe 'auth behavior' do
      it_behaves_like(
        'an endpoint with OpenID auth',
        scopes: AppealsApi::SupplementalClaims::V0::SupplementalClaimsController::OAUTH_SCOPES[:POST],
        success_status: :created
      ) do
        def make_request(auth_header)
          post(path, params:, headers: headers.merge(auth_header))
        end
      end
    end

    describe 'responses' do
      let(:created_supplemental_claim) { AppealsApi::SupplementalClaim.find(json_body.dig('data', 'id')) }
      let(:scopes) { %w[system/SupplementalClaims.write] }
      let(:json_body) { JSON.parse(response.body) }

      before do
        with_openid_auth(scopes) do |auth_header|
          post(path, params:, headers: headers.merge(auth_header))
        end
      end

      it 'returns 201 status' do
        expect(response).to have_http_status(:created)
      end

      it 'creates an SC record having api_version: "V0"' do
        expect(created_supplemental_claim.api_version).to eq('V0')
      end

      it 'includes the form_data with PII in the serialized response' do
        expect(json_body.dig('data', 'attributes', 'formData')).to be_present
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

      context 'when body is not JSON' do
        let(:params) { 'this-is-not-json' }

        it 'returns a 400 error' do
          expect(response).to have_http_status(:bad_request)
        end
      end

      context "with a veteran token where the token's ICN doesn't match the submitted ICN" do
        let(:scopes) { %w[veteran/SupplementalClaims.write] }
        let(:data) do
          default_data['data']['attributes']['veteran']['icn'] = other_icn
          default_data
        end

        it 'returns a 403 Forbidden error' do
          expect(response).to have_http_status(:forbidden)
        end
      end
    end
  end

  describe '#validate' do
    let(:path) { base_path 'forms/200995/validate' }
    let(:data) { default_data }
    let(:headers) { fixture_as_json 'supplemental_claims/v0/valid_200995_headers.json' }

    it_behaves_like(
      'an endpoint with OpenID auth',
      scopes: AppealsApi::SupplementalClaims::V0::SupplementalClaimsController::OAUTH_SCOPES[:POST]
    ) do
      def make_request(auth_header)
        post(path, params: data.to_json, headers: headers.merge(auth_header))
      end
    end

    context 'when veteran icn is not provided' do
      before do
        with_openid_auth(
          AppealsApi::SupplementalClaims::V0::SupplementalClaimsController::OAUTH_SCOPES[:POST]
        ) do |auth_header|
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

  describe '#download' do
    let(:sc) { create(:supplemental_claim_v0, status: 'submitted', api_version: 'V0', pdf_version: 'v3') }
    let(:generated_path) { base_path "/forms/200995/#{sc.id}/download" }

    # Delete pdfs generated by this describe group
    after(:all) do
      Dir.glob('200995-*.pdf').each { |f| FileUtils.rm_f(f) }
    end

    it_behaves_like(
      'watermarked pdf download endpoint',
      { factory: :supplemental_claim_v0 },
      described_class: AppealsApi::SupplementalClaims::V0::SupplementalClaimsController
    )

    describe 'auth behavior' do
      it_behaves_like('an endpoint with OpenID auth', scopes: %w[veteran/SupplementalClaims.read]) do
        def make_request(auth_header)
          get(generated_path, headers: auth_header)
        end
      end
    end

    describe 'icn parameter' do
      it_behaves_like 'GET endpoint with optional Veteran ICN parameter', {
        scope_base: 'SupplementalClaims',
        skip_ssn_lookup_tests: true
      }
    end
  end
end
