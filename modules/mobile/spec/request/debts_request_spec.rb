# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/helpers/sis_session_helper'
require_relative '../support/matchers/json_schema_matcher'

RSpec.describe 'debts', type: :request do
  include JsonSchemaMatchers

  let!(:user) { sis_user }

  describe 'GET /mobile/v0/debts' do
    context 'with a valid file number' do
      it 'fetches the veterans debt data' do
        VCR.use_cassette('bgs/people_service/person_data') do
          VCR.use_cassette('debts/get_letters') do
            get '/mobile/v0/debts', headers: sis_headers

            expect(response).to have_http_status(:ok)
            expect(response.body).to match_json_schema('debts', strict: true)
          end
        end
      end
    end

    context 'without a valid file number' do
      it 'returns a bad request error' do
        VCR.use_cassette('bgs/people_service/no_person_data') do
          VCR.use_cassette('debts/get_letters_empty_ssn') do
            get '/mobile/v0/debts', headers: sis_headers

            error_response = response.parsed_body.dig('errors', 0)
            expect(response).to have_http_status(:bad_request)
            expect(error_response).to eq({ 'title' => 'Bad Request',
                                           'detail' => 'Received a bad request response from the upstream server',
                                           'code' => 'DMC400', 'source' => 'DebtManagementCenter::DebtsService',
                                           'status' => '400' })
          end
        end
      end
    end

    context 'empty DMC response' do
      it 'handles an empty payload' do
        VCR.use_cassette('bgs/people_service/person_data') do
          VCR.use_cassette('debts/get_letters_empty_response') do
            get '/mobile/v0/debts', headers: sis_headers

            expect(response.parsed_body.dig('data', 'attributes')).to eq({ 'hasDependentDebts' => false,
                                                                           'debts' => [] })
          end
        end
      end
    end
  end
end
