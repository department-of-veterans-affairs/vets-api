# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

Rspec.describe 'AppealsApi::V1::Appeals', type: :request do
  include SchemaMatchers

  describe '#index' do
    let(:path) { '/services/appeals/appeals-status/v1/appeals' }
    let(:caseflow_cassette_name) { 'caseflow/appeals' }
    let(:mpi_cassette_name) { 'mpi/find_candidate/valid' }
    let(:va_user) { 'test.user@example.com' }
    let(:icn) { '1012667145V762142' }
    let(:ssn) { '796122306' }

    describe 'ICN parameter handling' do
      it_behaves_like(
        'GET endpoint with optional Veteran ICN parameter',
        {
          cassette: 'caseflow/appeals',
          path: '/services/appeals/appeals-status/v1/appeals',
          scope_base: 'AppealsStatus'
        }
      )
    end

    describe 'auth behavior' do
      it_behaves_like('an endpoint with OpenID auth', scopes: AppealsApi::V1::AppealsController::OAUTH_SCOPES[:GET]) do
        def make_request(auth_header)
          VCR.use_cassette(caseflow_cassette_name) do
            VCR.use_cassette(mpi_cassette_name) do
              get(path, params: { icn: }, headers: auth_header)
            end
          end
        end
      end
    end

    describe 'caseflow interaction' do
      let(:scopes) { %w[veteran/AppealsStatus.read] }
      let(:params) { {} }
      let(:error) { JSON.parse(response.body).dig('errors', 0) }

      before do
        allow(Rails.logger).to receive(:info)
        VCR.use_cassette(caseflow_cassette_name) do
          VCR.use_cassette(mpi_cassette_name) do
            with_openid_auth(scopes) { |auth_header| get(path, params:, headers: auth_header) }
          end
        end
      end

      describe 'when veteran is not found by SSN in caseflow' do
        let(:caseflow_cassette_name) { 'caseflow/not_found' }

        it 'returns a 404 error with a message that does not reference SSN' do
          expect(response).to have_http_status(:not_found)
          expect(error['detail']).not_to include('SSN')
        end
      end

      describe 'when caseflow throws a 500 error' do
        let(:caseflow_cassette_name) { 'caseflow/server_error' }

        it 'returns a 502 error instead' do
          expect(response).to have_http_status(:bad_gateway)
        end
      end
    end
  end
end
