# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

Rspec.describe 'AppealsApi::LegacyAppeals::V0::LegacyAppeals', type: :request do
  describe('#schema') do
    let(:path) { '/services/appeals/legacy-appeals/v0/schemas/params' }

    it 'renders the json schema for request params with shared refs' do
      with_openid_auth(AppealsApi::LegacyAppeals::V0::LegacyAppealsController::OAUTH_SCOPES[:GET]) do |auth_header|
        get(path, headers: auth_header)
      end

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['description']).to eq(
        'JSON Schema for Legacy Appeals endpoint parameters'
      )
      expect(response.body).to include('{"$ref":"icn.json"}')
    end

    it_behaves_like('an endpoint with OpenID auth',
                    scopes: AppealsApi::LegacyAppeals::V0::LegacyAppealsController::OAUTH_SCOPES[:GET]) do
      def make_request(auth_header)
        get(path, headers: auth_header)
      end
    end
  end

  describe '#index' do
    let(:path) { '/services/appeals/legacy-appeals/v0/legacy-appeals' }
    let(:icn) { '1012667145V762142' }
    let(:params) { { icn: } }
    let(:mpi_cassette_name) { 'mpi/find_candidate/valid' }
    let(:caseflow_cassette_name) { 'caseflow/legacy_appeals_get_by_ssn' }

    describe 'ICN parameter handling' do
      it_behaves_like(
        'GET endpoint with optional Veteran ICN parameter',
        {
          cassette: 'caseflow/legacy_appeals_get_by_ssn',
          path: '/services/appeals/legacy-appeals/v0/legacy-appeals',
          scope_base: 'LegacyAppeals'
        }
      )
    end

    describe 'auth behavior' do
      it_behaves_like('an endpoint with OpenID auth', scopes: %w[veteran/LegacyAppeals.read]) do
        def make_request(auth_header)
          VCR.use_cassette(caseflow_cassette_name) do
            VCR.use_cassette(mpi_cassette_name) do
              get(path, headers: auth_header, params:)
            end
          end
        end
      end
    end

    describe 'caseflow interaction' do
      let(:body) { JSON.parse(response.body) }
      let(:error) { body.dig('errors', 0) }
      let(:scopes) { %w[veteran/LegacyAppeals.read] }

      before do
        VCR.use_cassette(caseflow_cassette_name) do
          VCR.use_cassette(mpi_cassette_name) do
            with_openid_auth(scopes) { |auth_header| get(path, params:, headers: auth_header) }
          end
        end
      end

      it 'GETs legacy appeals from Caseflow successfully' do
        expect(response).to have_http_status(:ok)
        expect(body.dig('data', 0, 'attributes')).to include('latestSocSsocDate')
      end

      describe 'when veteran is not found by SSN in caseflow' do
        let(:caseflow_cassette_name) { 'caseflow/legacy_appeals_no_veteran_record' }

        it 'returns a 404 error with a message that does not reference SSN' do
          expect(response).to have_http_status(:not_found)
          expect(error['detail']).not_to include('SSN')
        end
      end

      describe 'when caseflow throws a 500 error' do
        let(:caseflow_cassette_name) { 'caseflow/legacy_appeals_server_error' }

        it 'returns a 502 error instead' do
          expect(response).to have_http_status(:bad_gateway)
        end
      end
    end
  end
end
