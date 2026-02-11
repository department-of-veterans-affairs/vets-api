# frozen_string_literal: true

require_relative '../../../support/helpers/rails_helper'
require_relative '../../../support/helpers/committee_helper'

require 'debt_management_center/models/debt_store'

RSpec.describe 'Mobile::V0::Debts', type: :request do
  include JsonSchemaMatchers
  include CommitteeHelper

  let!(:user) { sis_user }
  let(:meta) do
    {
      'meta' => { 'hasDependentDebts' => false }
    }
  end
  let(:debt5) do
    { 'type' => 'debts',
      'attributes' =>
        {
          'fileNumber' => '796043735',
          'payeeNumber' => '00',
          'personEntitled' => nil,
          'deductionCode' => '72',
          'benefitType' => 'CH33 Housing EDU',
          'diaryCode' => '914',
          'diaryCodeDescription' => 'Paid In Full',
          'amountOverpaid' => 123.34,
          'amountWithheld' => 321.76,
          'originalAr' => 321.76,
          'currentAr' => 123.34,
          'debtHistory' =>
            [{ 'date' => '08/08/2018', 'letterCode' => '608', 'description' => 'Full C&P Benefit Offset Notification' },
             { 'date' => '07/19/2018', 'letterCode' => '100',
               'description' => 'First Demand Letter - Inactive Benefits - Due Process' }],
          'fiscalTransactionData' => []
        } }
  end
  let(:debt4) do
    {
      'type' => 'debts',
      'attributes' =>
        {
          'fileNumber' => '796043735',
          'payeeNumber' => '00',
          'personEntitled' => nil,
          'deductionCode' => '74',
          'benefitType' => 'CH33 Student Tuition EDU',
          'diaryCode' => '914',
          'diaryCodeDescription' => 'Paid In Full',
          'amountOverpaid' => 123.34,
          'amountWithheld' => 475.0,
          'originalAr' => 2210.9,
          'currentAr' => 123.34,
          'debtHistory' =>
            [{ 'date' => '04/01/2017', 'letterCode' => '608', 'description' => 'Full C&P Benefit Offset Notification' },
             { 'date' => '11/18/2015', 'letterCode' => '130', 'description' => 'Debt Increase - Due Process' },
             { 'date' => '04/08/2015', 'letterCode' => '608', 'description' => 'Full C&P Benefit Offset Notification' },
             { 'date' => '03/26/2015', 'letterCode' => '100',
               'description' => 'First Demand Letter - Inactive Benefits - Due Process' }],
          'fiscalTransactionData' => []
        }
    }
  end
  let(:debt3) do
    {
      'type' => 'debts',
      'attributes' => {
        'fileNumber' => '796043735',
        'payeeNumber' => '00',
        'personEntitled' => nil,
        'deductionCode' => '71',
        'benefitType' => 'CH33 Books, Supplies/MISC EDU',
        'diaryCode' => '914',
        'diaryCodeDescription' => 'Paid In Full',
        'amountOverpaid' => 0.0,
        'amountWithheld' => 0.0,
        'originalAr' => 166.67,
        'currentAr' => 0.0,
        'debtHistory' => [],
        'fiscalTransactionData' => []
      }
    }
  end
  let(:debt2) do
    {
      'type' => 'debts',
      'attributes' =>
        { 'fileNumber' => '796043735',
          'payeeNumber' => '00',
          'personEntitled' => nil,
          'deductionCode' => '30',
          'benefitType' => 'Comp & Pen',
          'diaryCode' => '914',
          'diaryCodeDescription' => 'Paid In Full',
          'amountOverpaid' => 123.34,
          'amountWithheld' => 0.0,
          'originalAr' => 136.24,
          'currentAr' => 123.34,
          'debtHistory' =>
            [{ 'date' => '02/12/2009',
               'letterCode' => '487',
               'description' => 'Death Case Pending Action' }],
          'fiscalTransactionData' => [] }

    }
  end
  let(:debt1) do
    { 'type' => 'debts',
      'attributes' =>
        { 'fileNumber' => '796043735',
          'payeeNumber' => '00',
          'personEntitled' => nil,
          'deductionCode' => '30',
          'benefitType' => 'Comp & Pen',
          'diaryCode' => '914',
          'diaryCodeDescription' => 'Paid In Full',
          'amountOverpaid' => 123.34,
          'amountWithheld' => 50.0,
          'originalAr' => 1177.0,
          'currentAr' => 123.34,
          'debtHistory' =>
            [{ 'date' => '09/12/1998', 'letterCode' => '123', 'description' =>
              'Third Demand Letter - Potential Treasury Referral' },
             { 'date' => '09/13/1997', 'letterCode' => '123',
               'description' => 'Third Demand Letter - Potential Treasury Referral' },
             { 'date' => '04/01/1997', 'letterCode' => '122',
               'description' => 'Referall To Credit Reporting Agencies (CRA)' },
             { 'date' => '09/14/1996', 'letterCode' => '123',
               'description' => 'Third Demand Letter - Potential Treasury Referral' },
             { 'date' => '09/16/1995', 'letterCode' => '123',
               'description' => 'Third Demand Letter - Potential Treasury Referral' },
             { 'date' => '04/04/1995', 'letterCode' => '145',
               'description' =>
                 'Referall To Credit Alert Interactive Verification Reporting System (CAIVRS) In 30 Days' },
             { 'date' => '02/14/1995', 'letterCode' => '117',
               'description' => 'Second Demand Letter - Potential Negative Referral' },
             { 'date' => '11/15/1994', 'letterCode' => '603', 'description' => 'Late Or Missed Payment Notification' },
             { 'date' => '09/10/1994', 'letterCode' => '123',
               'description' => 'Third Demand Letter - Potential Treasury Referral' }],
          'fiscalTransactionData' => [] } }
  end

  before do
    allow(Flipper).to receive(:enabled?).with(:mobile_debts_enabled, anything).and_return(true)
  end

  context 'when mobile_debts_enabled feature flag is disabled' do
    before do
      allow(Flipper).to receive(:enabled?).with(:mobile_debts_enabled, anything).and_return(false)
    end

    it 'returns forbidden for index' do
      get '/mobile/v0/debts', headers: sis_headers

      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body['error']['code']).to eq('FEATURE_NOT_AVAILABLE')
    end

    it 'returns forbidden for show' do
      get '/mobile/v0/debts/some-id', headers: sis_headers

      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body['error']['code']).to eq('FEATURE_NOT_AVAILABLE')
    end
  end

  describe 'GET /mobile/v0/debts' do
    context 'with a valid file number' do
      it 'fetches the veterans debt data' do
        VCR.use_cassette('bgs/people_service/person_data') do
          VCR.use_cassette('debts/get_letters') do
            get '/mobile/v0/debts', headers: sis_headers
            assert_schema_conform(200)
            expect(response.body).to match_json_schema('debts', strict: true)
            debt_data = response.parsed_body['data'].map { |d| d.except('id') }
            expect(debt_data).to include(debt1)
            expect(debt_data).to include(debt2)
            expect(debt_data).to include(debt4)
            expect(debt_data).to include(debt5)
          end
        end
      end
    end

    context 'when count_only is true' do
      it 'returns only the count of debts' do
        VCR.use_cassette('bgs/people_service/person_data') do
          VCR.use_cassette('debts/get_letters_count_only') do
            get '/mobile/v0/debts', params: { countOnly: true }, headers: sis_headers
            expect(response.parsed_body['debtsCount']).to eq(5)
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
            assert_schema_conform(400)
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
            assert_schema_conform(200)
            expect(response.parsed_body).to eq({ 'data' => [], 'meta' => { 'hasDependentDebts' => false } })
          end
        end
      end
    end

    context 'with missing fiscalTransactionData' do
      it 'handles missing fiscalTransactionData key gracefully in list response' do
        VCR.use_cassette('bgs/people_service/person_data') do
          VCR.use_cassette('debts/get_letters') do
            # Mock the service to return debt data without fiscalTransactionData
            allow_any_instance_of(DebtManagementCenter::DebtsService).to receive(:get_debts).and_return(
              {
                debts: [
                  {
                    'fileNumber' => '796043735',
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
                    'debtHistory' => []
                  }
                ]
              }
            )

            get '/mobile/v0/debts', headers: sis_headers
            assert_schema_conform(200)
            expect(response.body).to match_json_schema('debts', strict: true)
            debt_data = response.parsed_body['data'].first
            expect(debt_data['attributes']['fiscalTransactionData']).to eq([])
          end
        end
      end

      it 'handles nil fiscalTransactionData gracefully in list response' do
        VCR.use_cassette('bgs/people_service/person_data') do
          VCR.use_cassette('debts/get_letters') do
            # Mock the service to return debt data with nil fiscalTransactionData
            allow_any_instance_of(DebtManagementCenter::DebtsService).to receive(:get_debts).and_return(
              {
                debts: [
                  {
                    'fileNumber' => '796043735',
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
                    'debtHistory' => [],
                    'fiscalTransactionData' => nil
                  }
                ]
              }
            )

            get '/mobile/v0/debts', headers: sis_headers
            assert_schema_conform(200)
            expect(response.body).to match_json_schema('debts', strict: true)
            debt_data = response.parsed_body['data'].first
            expect(debt_data['attributes']['fiscalTransactionData']).to eq([])
          end
        end
      end
    end
  end

  describe 'GET /mobile/v0/debts/:id' do
    let(:debt_id) { '2b41479f-2181-4016-9f77-3359c3ecee74' }
    let(:debt) do
      {
        'type' => 'debts',
        'attributes' =>
          { 'fileNumber' => '796043735',
            'payeeNumber' => '00',
            'personEntitled' => nil,
            'deductionCode' => '30',
            'benefitType' => 'Comp & Pen',
            'diaryCode' => '914',
            'diaryCodeDescription' => 'Paid In Full',
            'amountOverpaid' => 123.34,
            'amountWithheld' => 50.0,
            'originalAr' => 1177.0,
            'currentAr' => 123.34,
            'debtHistory' =>
              [{ 'date' => '09/12/1998', 'letterCode' => '123',
                 'description' => 'Third Demand Letter - Potential Treasury Referral' }],
            'fiscalTransactionData' => [] }
      }
    end

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
                      'description' => 'Third Demand Letter - Potential Treasury Referral' }],
                 'fiscalTransactionData' => [] }]
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

            assert_schema_conform(200)
            expect(response.body).to match_json_schema('debt', strict: true)
            debt_data = response.parsed_body['data'].except('id')
            expect(debt_data).to include(debt)
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
            assert_schema_conform(400)
            expect(error_response).to eq({ 'title' => 'Bad Request',
                                           'detail' => 'Received a bad request response from the upstream server',
                                           'code' => 'DMC400', 'source' => 'DebtManagementCenter::DebtsService',
                                           'status' => '400' })
          end
        end
      end
    end

    context 'with missing fiscalTransactionData' do
      let(:debt_without_fiscal_data) do
        {
          'type' => 'debts',
          'attributes' =>
            { 'fileNumber' => '796043735',
              'payeeNumber' => '00',
              'personEntitled' => nil,
              'deductionCode' => '30',
              'benefitType' => 'Comp & Pen',
              'diaryCode' => '914',
              'diaryCodeDescription' => 'Paid In Full',
              'amountOverpaid' => 123.34,
              'amountWithheld' => 50.0,
              'originalAr' => 1177.0,
              'currentAr' => 123.34,
              'debtHistory' =>
                [{ 'date' => '09/12/1998', 'letterCode' => '123',
                   'description' => 'Third Demand Letter - Potential Treasury Referral' }],
              'fiscalTransactionData' => [] }
        }
      end

      let(:load_debt_store_without_fiscal_data) do
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

      it 'handles missing fiscalTransactionData key gracefully' do
        VCR.use_cassette('bgs/people_service/person_data') do
          VCR.use_cassette('debts/get_letters') do
            load_debt_store_without_fiscal_data
            get "/mobile/v0/debts/#{debt_id}", headers: sis_headers

            assert_schema_conform(200)
            expect(response.body).to match_json_schema('debt', strict: true)
            debt_data = response.parsed_body['data'].except('id')
            expect(debt_data).to include(debt_without_fiscal_data)
            expect(debt_data['attributes']['fiscalTransactionData']).to eq([])
          end
        end
      end

      it 'handles nil fiscalTransactionData gracefully' do
        VCR.use_cassette('bgs/people_service/person_data') do
          VCR.use_cassette('debts/get_letters') do
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
                            'description' => 'Third Demand Letter - Potential Treasury Referral' }],
                       'fiscalTransactionData' => nil }]
            debts[0]['id'] = debt_id
            debt_store = DebtManagementCenter::DebtStore.find_or_build(user.uuid)
            debt_store.update(debts:, uuid: user.uuid)

            get "/mobile/v0/debts/#{debt_id}", headers: sis_headers

            assert_schema_conform(200)
            expect(response.body).to match_json_schema('debt', strict: true)
            debt_data = response.parsed_body['data'].except('id')
            expect(debt_data).to include(debt_without_fiscal_data)
            expect(debt_data['attributes']['fiscalTransactionData']).to eq([])
          end
        end
      end
    end
  end
end
