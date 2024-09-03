# frozen_string_literal: true

require_relative '../../../support/helpers/rails_helper'

require 'debt_management_center/models/debt_store'

RSpec.describe 'Mobile::V0::Debts', type: :request do
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
            expect(response.parsed_body).to eq({ 'data' => [], 'meta' => { 'hasDependentDebts' => false } })
          end
        end
      end
    end
  end

  describe 'GET /mobile/v0/debts/:id' do
    let(:debt_id) { '2b41479f-2181-4016-9f77-3359c3ecee74' }

    let(:load_debt_store) do
      debts = [{ 'fileNumber' => '796043735',
                 'payeeNumber' => '00',
                 'personEntitled' => nil,
                 'deductionCode' => '30',
                 'benefitType' => 'Comp & Pen',
                 'diaryCode' => '914',
                 'diaryCodeDescription' => 'Paid In Full',
                 'amountOverpaid' => 123.34,
                 'amountWithheld' => 50.0,
                 'originalAR' => 1177.0,
                 'currentAR' => 123.34,
                 'debtHistory' =>
                  [{ 'date' => '09/12/1998', 'letterCode' => '123',
                     'description' => 'Third Demand Letter - Potential Treasury Referral' }] }]
      debts[0]['id'] = debt_id
      debt_store = DebtManagementCenter::DebtStore.find_or_build(user.uuid)
      debt_store.update(debts:, uuid: user.uuid)
    end

    context 'with a valid file number' do
      it 'fetches the veterans debt data' do
        VCR.use_cassette('bgs/people_service/person_data') do
          VCR.use_cassette('debts/get_letters') do
            load_debt_store
            get "/mobile/v0/debts/#{debt_id}", headers: sis_headers

            expect(response).to have_http_status(:ok)
            expect(response.body).to match_json_schema('debt', strict: true)
          end
        end
      end
    end

    context 'without a valid file number' do
      it 'returns a bad request error' do
        VCR.use_cassette('bgs/people_service/no_person_data') do
          VCR.use_cassette('debts/get_letters_empty_ssn') do
            load_debt_store
            get "/mobile/v0/debts/#{debt_id}", headers: sis_headers

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
  end
end
