# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

describe AppealsApi::V1::AppealsController, type: :request do
  describe '#index' do
    include SchemaMatchers

    let(:caseflow_cassette_name) { 'caseflow/appeals' }
    let(:mpi_cassette_name) { 'mpi/find_candidate/valid' }
    let(:icn) { '1008714701V416111' }
    let(:ssn) { '796122306' }
    let(:consumer_username) { 'TestConsumer' }
    let(:va_user) { 'text.user' }
    let(:headers) { { 'X-Consumer-Username' => consumer_username, 'X-VA-User' => va_user } }

    before do
      allow(Rails.logger).to receive(:info)

      VCR.use_cassette(caseflow_cassette_name) do
        VCR.use_cassette(mpi_cassette_name) do
          with_openid_auth(described_class::OAUTH_SCOPES[:GET]) do |auth_header|
            get '/services/appeals/v1/appeals', params: { icn: }, headers: auth_header.merge(headers)
          end
        end
      end
    end

    describe 'success' do
      it 'returns appeals' do
        expect(response).to have_http_status(:ok)
        expect(response.body).to be_a(String)
        expect(response).to match_response_schema('appeals')
      end

      it 'logs the caseflow request and response' do
        expect(Rails.logger).to have_received(:info).with(
          'Caseflow Request',
          { 'va_user' => va_user, 'lookup_identifier' => Digest::SHA2.hexdigest(ssn) }
        )
        expect(Rails.logger).to have_received(:info).with(
          'Caseflow Response',
          { 'va_user' => va_user, 'first_appeal_id' => '1196201', 'appeal_count' => 3 }
        )
      end
    end

    describe 'errors' do
      let(:error) { JSON.parse(response.body)['errors'].first }

      describe 'with missing X-VA-User header' do
        let(:headers) { { 'X-Consumer-Username' => consumer_username } }

        it 'returns a 400 error' do
          expect(response).to have_http_status(:bad_request)
          expect(error['detail']).to include('X-VA-User')
        end
      end

      describe 'with missing ICN parameter' do
        let(:icn) {}

        it 'returns a 400 error' do
          expect(response).to have_http_status(:bad_request)
          expect(error['detail']).to include("'icn'")
        end
      end

      describe 'with malformed ICN parameter' do
        let(:icn) { 'not-an-icn' }

        it 'returns a 422 error' do
          expect(response).to have_http_status(:unprocessable_entity)
        end
      end

      describe 'when veteran SSN is not found by ICN in MPI' do
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
  end
end
