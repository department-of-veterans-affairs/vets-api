# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

describe AppealsApi::LegacyAppeals::V0::LegacyAppealsController, type: :request do
  describe('#schema') do
    let(:path) { '/services/appeals/legacy_appeals/v0/schemas/headers' }

    it 'renders the json schema for request headers with shared refs' do
      with_openid_auth(described_class::OAUTH_SCOPES[:GET]) do |auth_header|
        get(path, headers: auth_header)
      end

      expect(response.status).to eq(200)
      expect(JSON.parse(response.body)['description']).to eq(
        'JSON Schema for Legacy Appeals endpoint headers (Decision Reviews API)'
      )
      expect(response.body).to include('{"$ref":"non_blank_string.json"}')
    end

    it_behaves_like('an endpoint with OpenID auth', scopes: described_class::OAUTH_SCOPES[:GET]) do
      def make_request(auth_header)
        get(path, headers: auth_header)
      end
    end
  end

  describe '#index' do
    let(:path) { '/services/appeals/legacy_appeals/v0/legacy_appeals' }
    let(:headers) { {} }
    let(:ssn) { '502628285' }
    let(:icn) { '1234567890V012345' }

    before do
      headers['X-VA-SSN'] = ssn if ssn.present?
      headers['X-VA-ICN'] = icn if icn.present?
    end

    context 'when all required fields provided' do
      it 'GETs legacy appeals from Caseflow successfully' do
        VCR.use_cassette('caseflow/legacy_appeals_get_by_ssn') do
          get_legacy_appeals(headers)

          expect(response).to have_http_status(:ok)
          json = JSON.parse(response.body)
          expect(json['data']).not_to be_nil
          expect(json['data'][0]['attributes']).to include('latestSocSsocDate')
        end
      end
    end

    context 'when icn not provided' do
      let(:icn) { nil }

      it 'returns a 422 error with details' do
        get_legacy_appeals(headers)

        expect(response).to have_http_status(:unprocessable_entity)
        error = JSON.parse(response.body)['errors'][0]
        expect(error['detail']).to include('One or more expected fields were not found')
        expect(error['meta']['missing_fields']).to include('X-VA-ICN')
      end
    end

    context 'when icn does not meet length requirements' do
      let(:icn) { '229384' }

      it 'returns a 422 error with details' do
        get_legacy_appeals(headers)

        expect(response).to have_http_status(:unprocessable_entity)
        error = JSON.parse(response.body)['errors'][0]
        expect(error['title']).to eql('Invalid length')
        expect(error['detail']).to include("'#{icn}' did not fit within the defined length limits")
      end
    end

    context 'when icn does not meet pattern requirements' do
      let(:icn) { '22938439103910392' }

      it 'returns a 422 error with details' do
        get_legacy_appeals(headers)

        expect(response).to have_http_status(:unprocessable_entity)
        error = JSON.parse(response.body)['errors'][0]
        expect(error['title']).to eql('Invalid pattern')
        expect(error['detail']).to include("'#{icn}' did not match the defined pattern")
      end
    end
  end

  def get_legacy_appeals(headers)
    with_openid_auth(described_class::OAUTH_SCOPES[:GET]) do |auth_header|
      get(path, headers: headers.merge(auth_header))
    end
  end
end
