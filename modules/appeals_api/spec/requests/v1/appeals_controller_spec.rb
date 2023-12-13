# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

describe AppealsApi::V1::AppealsController, type: :request do
  describe '#index' do
    include SchemaMatchers

    let(:caseflow_cassette_name) { 'caseflow/appeals' }
    let(:mpi_cassette_name) { 'mpi/find_candidate/valid' }
    let(:icn) { '1012667145V762142' }
    let(:ssn) { '796122306' }
    let(:consumer_username) { 'TestConsumer' }
    let(:headers) { { 'X-Consumer-Username' => consumer_username } }
    let(:scopes) { described_class::OAUTH_SCOPES[:GET] }
    let(:params) { {} }

    describe '#index' do
      let(:path) { '/services/appeals/v1/appeals' }

      before do
        allow(Rails.logger).to receive(:info)
        VCR.use_cassette(caseflow_cassette_name) do
          VCR.use_cassette(mpi_cassette_name) do
            with_openid_auth(scopes) do |auth_header|
              get(path, params:, headers: auth_header.merge(headers))
            end
          end
        end
      end

      describe 'successes' do
        context 'with veteran scope' do
          let(:scopes) { %w[veteran/AppealsStatus.read] }

          context 'without ICN parameter' do
            it 'returns appeals' do
              expect(response).to have_http_status(:ok)
              expect(response).to match_response_schema('appeals')
            end

            it 'logs the caseflow request and response' do
              expect(Rails.logger).to have_received(:info).with(
                'Caseflow Request',
                { 'lookup_identifier' => Digest::SHA2.hexdigest(ssn) }
              )
              expect(Rails.logger).to have_received(:info).with(
                'Caseflow Response',
                { 'first_appeal_id' => '1196201', 'appeal_count' => 3 }
              )
            end
          end

          context 'with correct, optional ICN parameter' do
            let(:params) { { icn: } }

            it 'returns appeals' do
              expect(response).to have_http_status(:ok)
              expect(response).to match_response_schema('appeals')
            end
          end
        end

        context 'with system scope' do
          let(:scopes) { %w[system/AppealsStatus.read] }
          let(:params) { { icn: } }

          it 'returns appeals' do
            expect(response).to have_http_status(:ok)
            expect(response).to match_response_schema('appeals')
          end
        end

        context 'with representative scope' do
          let(:scopes) { %w[representative/AppealsStatus.read] }
          let(:params) { { icn: } }

          it 'returns appeals' do
            expect(response).to have_http_status(:ok)
            expect(response).to match_response_schema('appeals')
          end
        end
      end

      describe 'errors' do
        let(:error) { JSON.parse(response.body).dig('errors', 0) }

        describe 'with veteran scope' do
          describe 'with incorrect ICN parameter' do
            let(:params) { { icn: '1234567890V123456' } }

            it 'returns a 403 error' do
              expect(response).to have_http_status(:forbidden)
              expect(error['detail']).to include('Veterans may access only their own records')
            end
          end
        end

        describe 'with representative scope' do
          let(:scopes) { %w[representative/AppealsStatus.read] }

          describe 'with missing ICN parameter' do
            it 'returns a 400 error' do
              expect(response).to have_http_status(:bad_request)
              expect(error['detail']).to include('required parameter "icn"')
            end
          end
        end

        describe 'with system scope' do
          describe 'with missing ICN parameter' do
            let(:scopes) { %w[system/AppealsStatus.read] }

            it 'returns a 400 error' do
              expect(response).to have_http_status(:bad_request)
              expect(error['detail']).to include('required parameter "icn"')
            end
          end
        end

        describe 'with malformed ICN parameter' do
          let(:params) { { icn: 'not-an-icn' } }

          it 'returns a 422 error' do
            expect(response).to have_http_status(:unprocessable_entity)
          end
        end

        describe 'when veteran SSN is not found in MPI based on the provided ICN' do
          let(:mpi_cassette_name) { 'mpi/find_candidate/icn_not_found' }

          it 'returns a 404 error with a message that does not reference SSN' do
            expect(response).to have_http_status(:not_found)
            expect(error['detail']).not_to include('SSN')
          end
        end

        describe 'when MPI throws an error' do
          let(:mpi_cassette_name) { 'mpi/find_candidate/internal_server_error' }

          it 'returns a 502 error instead' do
            expect(response).to have_http_status(:bad_gateway)
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

      it_behaves_like('an endpoint with OpenID auth', scopes: described_class::OAUTH_SCOPES[:GET]) do
        def make_request(auth_header)
          VCR.use_cassette(caseflow_cassette_name) do
            VCR.use_cassette(mpi_cassette_name) do
              get(path, params: { icn: }, headers: auth_header.merge(headers))
            end
          end
        end
      end
    end
  end
end
