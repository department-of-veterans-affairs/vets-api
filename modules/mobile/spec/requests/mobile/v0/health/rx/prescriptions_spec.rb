# frozen_string_literal: true

require_relative '../../../../../support/helpers/rails_helper'
require 'support/rx_client_helpers'
require 'support/shared_examples_for_mhv'
require 'vets/collection'

RSpec.describe 'health/rx/prescriptions', type: :request do
  include JsonSchemaMatchers
  include Rx::ClientHelpers

  let!(:user) { sis_user(:mhv, mhv_account_type:) }
  let(:mhv_account_type) { 'Premium' }
  let(:upstream_mhv_history_url) { 'https://mhv-api.example.com/v1/pharmacy/ess/medications' }

  before do
    allow(Settings.mhv.rx).to receive(:collection_caching_enabled).and_return(true)
    allow(Rx::Client).to receive(:new).and_return(authenticated_client)
    allow_any_instance_of(User).to receive(:mhv_user_account).and_return(OpenStruct.new(patient: true))
    Timecop.freeze(Time.zone.parse('2025-04-21T00:00:00.000Z'))
  end

  after do
    Timecop.return
  end

  describe 'GET /mobile/v0/health/rx/prescriptions/refill', :aggregate_failures do
    it 'returns all successful refills' do
      VCR.use_cassette('mobile/rx_refill/prescriptions/refills_prescriptions') do
        put '/mobile/v0/health/rx/prescriptions/refill', params: { ids: %w[21530889 21539942] }, headers: sis_headers
      end
      expect(response).to have_http_status(:ok)
      attributes = response.parsed_body.dig('data', 'attributes')
      expect(attributes).to eq({ 'failedStationList' => '',
                                 'successfulStationList' => 'DAYT29, DAYT29',
                                 'lastUpdatedTime' => 'Thu, 08 Dec 2022 12:11:33 EST',
                                 'prescriptionList' => nil,
                                 'failedPrescriptionIds' => [],
                                 'errors' => [],
                                 'infoMessages' => [] })
    end

    context 'refill multiple prescription, one of which is non-refillable' do
      it 'returns error and successful refills' do
        VCR.use_cassette('mobile/rx_refill/prescriptions/refills_prescriptions_with_error') do
          put '/mobile/v0/health/rx/prescriptions/refill', params: { ids: %w[7417954 6970769 8398465] },
                                                           headers: sis_headers
        end
        expect(response).to have_http_status(:ok)
        attributes = response.parsed_body.dig('data', 'attributes')
        expect(attributes).to eq({ 'failedStationList' => '',
                                   'successfulStationList' => 'SLC4, VAMCSLC-OUTPTRX',
                                   'lastUpdatedTime' => 'Tue, 30 Aug 2022 12:30:38 EDT',
                                   'prescriptionList' => nil,
                                   'failedPrescriptionIds' => ['8398465'],
                                   'errors' => [{ 'errorCode' => 139,
                                                  'developerMessage' =>
                                                    'Prescription not refillable for id : 8398465',
                                                  'message' => 'Prescription is not Refillable' }],
                                   'infoMessages' => [] })
      end
    end

    context 'refill multiple non-refillable prescriptions' do
      it 'returns error and successful refills' do
        VCR.use_cassette('mobile/rx_refill/prescriptions/refills_prescriptions_with_multiple_errors') do
          put '/mobile/v0/health/rx/prescriptions/refill', params: { ids: %w[7417954 6970769 8398465] },
                                                           headers: sis_headers
        end
        expect(response).to have_http_status(:ok)
        attributes = response.parsed_body.dig('data', 'attributes')
        expect(attributes).to eq({ 'failedStationList' => '',
                                   'successfulStationList' => 'SLC4, VAMCSLC-OUTPTRX',
                                   'lastUpdatedTime' => 'Tue, 30 Aug 2022 12:30:38 EDT',
                                   'prescriptionList' => nil,
                                   'failedPrescriptionIds' => %w[7417954 6970769 8398465],
                                   'errors' => [{ 'errorCode' => 139,
                                                  'developerMessage' =>
                                                    'Prescription not refillable for id : 7417954',
                                                  'message' => 'Prescription is not Refillable' },
                                                { 'errorCode' => 139,
                                                  'developerMessage' =>
                                                    'Prescription not refillable for id : 6970769',
                                                  'message' => 'Prescription is not Refillable' },
                                                { 'errorCode' => 139,
                                                  'developerMessage' =>
                                                    'Prescription not refillable for id : 8398465',
                                                  'message' => 'Prescription is not Refillable' }],
                                   'infoMessages' => [] })
      end
    end

    context 'attempt to refill with non array of ids' do
      it 'returns Invalid Field Value 400 error' do
        put '/mobile/v0/health/rx/prescriptions/refill', params: { ids: '8398465' }, headers: sis_headers
        expect(response).to have_http_status(:bad_request)
        errors = response.parsed_body['errors']
        expect(errors).to eq([{ 'title' => 'Invalid field value',
                                'detail' =>
                                  '"8398465" is not a valid value for "ids"',
                                'code' => '103',
                                'status' => '400' }])
      end
    end

    context 'refill multiple prescription, one of which does not exist' do
      it 'returns error and successful refills' do
        VCR.use_cassette('mobile/rx_refill/prescriptions/refills_prescriptions_not_found') do
          put '/mobile/v0/health/rx/prescriptions/refill', params: { ids: %w[21530889 21539942 123456] },
                                                           headers: sis_headers
        end
        expect(response).to have_http_status(:ok)
        attributes = response.parsed_body.dig('data', 'attributes')
        expect(attributes).to eq({ 'failedStationList' => '',
                                   'successfulStationList' => 'DAYT29, DAYT29',
                                   'lastUpdatedTime' => 'Thu, 08 Dec 2022 12:18:33 EST',
                                   'prescriptionList' => nil,
                                   'failedPrescriptionIds' => ['123456'],
                                   'errors' => [{ 'errorCode' => 135,
                                                  'developerMessage' =>
                                                    'Prescription not found for id : 123456',
                                                  'message' => 'Prescription not found' }],
                                   'infoMessages' => [] })
      end
    end

    # Temporarily removing test until we can figure out how to handle cache
    # context 'prescription cache is present on refill' do
    #   it 'flushes prescription cache on refill' do
    #     set_cache

    #     VCR.use_cassette('mobile/rx_refill/prescriptions/refills_prescriptions') do
    #       put '/mobile/v0/health/rx/prescriptions/refill', params: { ids: %w[21530889 21539942] },
    #                                                        headers: sis_headers
    #     end

    #     get '/mobile/v0/health/rx/prescriptions', headers: sis_headers

    #     assert_requested :get, upstream_mhv_history_url, times: 1
    #   end
    # end
  end

  describe 'GET /mobile/v0/health/rx/prescriptions', :aggregate_failures do
    context 'with a valid MHV response and no failed facilities' do
      it 'returns 200' do
        VCR.use_cassette('rx_client/prescriptions/gets_a_list_of_all_prescriptions_v1') do
          get '/mobile/v0/health/rx/prescriptions', headers: sis_headers
        end
        expect(response).to have_http_status(:ok)
        expect(response.body).to match_json_schema('prescription')
      end

      it 'includes sortedDispensedDate field' do
        VCR.use_cassette('rx_client/prescriptions/gets_a_list_of_all_prescriptions_v1') do
          get '/mobile/v0/health/rx/prescriptions', headers: sis_headers
        end

        expect(response).to have_http_status(:ok)
        data = response.parsed_body['data']

        prescriptions_with_dates = data.select { |rx| rx.dig('attributes', 'sortedDispensedDate').present? }
        expect(prescriptions_with_dates).not_to be_empty
      end
    end

    context 'when user does not have mhv access' do
      let!(:user) { sis_user }

      before do
        allow_any_instance_of(User).to receive(:mhv_user_account).and_return(OpenStruct.new(patient: false))
      end

      it 'returns a 403 forbidden response' do
        VCR.use_cassette('rx_client/prescriptions/gets_a_list_of_all_prescriptions_v1') do
          get '/mobile/v0/health/rx/prescriptions', headers: sis_headers
        end
        expect(response).to have_http_status(:forbidden)
        expect(response.parsed_body).to eq({ 'errors' =>
                                               [{ 'title' => 'Forbidden',
                                                  'detail' => 'User does not have access to the requested resource',
                                                  'code' => '403',
                                                  'status' => '403' }] })
      end
    end

    context 'when there are expired/discontinued meds older than 180 days' do
      it 'filters out the old meds' do
        params = { page: { number: 1, size: 104 }, filter: { refill_status: { eq: 'discontinued,expired' } } }

        VCR.use_cassette('rx_client/prescriptions/gets_a_list_of_all_prescriptions_v1') do
          get '/mobile/v0/health/rx/prescriptions', params:, headers: sis_headers
        end

        expect(response).to have_http_status(:ok)
        expect(response.body).to match_json_schema('prescription')

        expect(response.parsed_body['meta']['pagination']['totalEntries']).to eq(104)

        old_med = response.parsed_body['data'].find do |rx|
          rx['attributes']['expirationDate'] < 180.days.ago
        end

        expect(old_med).to be_falsey
      end
    end

    context 'veteran has Non-VA medication' do
      it 'filters out all Non-VA meds' do
        params = { page: { number: 1, size: 100 }, filter: { refill_status: { eq: 'active' } } }

        VCR.use_cassette('rx_client/prescriptions/gets_a_list_of_all_prescriptions_v1') do
          get '/mobile/v0/health/rx/prescriptions', params:, headers: sis_headers
        end
        expect(response).to have_http_status(:ok)
        expect(response.body).to match_json_schema('prescription')

        expect(response.parsed_body['meta']['pagination']['totalEntries']).to eq(2)

        # Only Non-VA meds can have missing prescriptionsName
        missing_name_med = response.parsed_body['data'].find do |rx|
          rx['attributes']['prescriptionName'].nil?
        end

        expect(missing_name_med).to be_falsey
      end
    end

    describe 'feature mhv_medications_display_pending_meds' do
      context 'when mhv_medications_display_pending_meds is set to true"' do
        before do
          Flipper.enable_actor(:mhv_medications_display_pending_meds, user) # rubocop:disable Project/ForbidFlipperToggleInSpecs
        end

        it 'responds to GET #index with pending meds included in list' do
          VCR.use_cassette('rx_client/prescriptions/gets_a_list_of_prescriptions_w_pending_meds') do
            get '/mobile/v0/health/rx/prescriptions', headers: sis_headers
          end

          expect(response).to be_successful
          expect(response.body).to be_a(String)
          expect(response.body).to match_json_schema('prescription')
          expect(JSON.parse(response.body)['data']).to be_truthy

          expect(response.parsed_body['meta']['pagination']['totalEntries']).to eq(146)
        end
      end

      context 'when mhv_medications_display_pending_meds is set to false"' do
        before do
          Flipper.disable(:mhv_medications_display_pending_meds) # rubocop:disable Project/ForbidFlipperToggleInSpecs
        end

        it 'responds to GET #index with pending meds not included in list' do
          VCR.use_cassette('rx_client/prescriptions/gets_a_list_of_prescriptions_w_pending_meds') do
            get '/mobile/v0/health/rx/prescriptions', headers: sis_headers
          end

          expect(response).to be_successful
          expect(response.body).to be_a(String)
          expect(response.body).to match_json_schema('prescription')
          expect(JSON.parse(response.body)['data']).to be_truthy

          expect(response.parsed_body['meta']['pagination']['totalEntries']).to eq(135)
        end
      end
    end

    describe 'error cases' do
      it 'converts Faraday::TimeoutError to 408' do
        allow_any_instance_of(Faraday::Connection).to receive(:get).and_raise(Faraday::TimeoutError)

        get '/mobile/v0/health/rx/prescriptions', headers: sis_headers
        expect(response).to have_http_status(:request_timeout)
      end
    end

    describe 'pagination parameters' do
      it 'forms meta data' do
        params = { page: { number: 2, size: 3 } }

        VCR.use_cassette('rx_client/prescriptions/gets_a_list_of_all_prescriptions_v1') do
          get '/mobile/v0/health/rx/prescriptions', params:, headers: sis_headers
        end
        expect(response).to have_http_status(:ok)
        expect(response.body).to match_json_schema('prescription')
        expect(response.parsed_body['meta']['pagination']).to eq({ 'currentPage' => 2,
                                                                   'perPage' => 3,
                                                                   'totalPages' => 49,
                                                                   'totalEntries' => 146 })
      end
    end

    describe 'filtering parameters' do
      context 'filter by refill status' do
        params = { filter: { refill_status: { eq: 'refillinprocess' } } }

        it 'returns all prescriptions that are refillinprocess status' do
          VCR.use_cassette('rx_client/prescriptions/gets_a_list_of_all_prescriptions_v1') do
            get '/mobile/v0/health/rx/prescriptions', params:, headers: sis_headers
          end
          expect(response).to have_http_status(:ok)
          expect(response.body).to match_json_schema('prescription')

          refill_statuses = response.parsed_body['data'].map { |d| d.dig('attributes', 'refillStatus') }.uniq
          expect(refill_statuses).to eq(['refillinprocess'])
        end
      end

      context 'filter by multiple fields' do
        params = { filter: { is_refillable: { eq: 'false' }, is_trackable: { eq: 'true' } } }

        it 'returns all prescriptions that are trackable but not refillable' do
          VCR.use_cassette('rx_client/prescriptions/gets_a_list_of_all_prescriptions_v1') do
            get '/mobile/v0/health/rx/prescriptions', params:, headers: sis_headers
          end
          expect(response).to have_http_status(:ok)
          expect(response.body).to match_json_schema('prescription')
          expect(response.parsed_body['data'].size).to eq(1)
          expect(response.parsed_body.dig('data', 0, 'attributes', 'isTrackable')).to be(true)
          expect(response.parsed_body.dig('data', 0, 'attributes', 'isRefillable')).to be(false)
        end
      end

      context 'filter by multiple types of refill_statuses' do
        let(:params) do
          { page: { number: 1, size: 100 }, filter: { refill_status: { eq: 'refillinprocess,active' } } }
        end

        it 'returns all prescriptions that are both trackable and refillable' do
          VCR.use_cassette('rx_client/prescriptions/gets_a_list_of_all_prescriptions_v1') do
            get '/mobile/v0/health/rx/prescriptions', params:, headers: sis_headers
          end
          expect(response).to have_http_status(:ok)
          expect(response.body).to match_json_schema('prescription')
          refill_statuses = response.parsed_body['data'].map { |d| d.dig('attributes', 'refillStatus') }.uniq

          expect(refill_statuses).to eq(%w[refillinprocess active])
        end
      end

      context 'filter by not equal to refill status' do
        params = { page: { number: 1, size: 59 }, filter: { refill_status: { not_eq: 'refillinprocess' } } }

        it 'returns all prescriptions that are not refillinprocess status' do
          VCR.use_cassette('rx_client/prescriptions/gets_a_list_of_all_prescriptions_v1') do
            get '/mobile/v0/health/rx/prescriptions', params:, headers: sis_headers
          end
          expect(response).to have_http_status(:ok)
          expect(response.body).to match_json_schema('prescription')

          refill_statuses = response.parsed_body['data'].map { |d| d.dig('attributes', 'refillStatus') }.uniq

          # does not include refillinprocess
          expect(refill_statuses).to include('expired', 'discontinued', 'activeParked', 'active', 'submitted')
        end
      end

      context 'invalid filter option' do
        params = { filter: { quantity: { eq: '8' } } }

        it 'cannot filter by unexpected field' do
          VCR.use_cassette('rx_client/prescriptions/gets_a_list_of_all_prescriptions_v1') do
            get '/mobile/v0/health/rx/prescriptions', params:, headers: sis_headers
          end
          expect(response).to have_http_status(:bad_request)
          expect(response.parsed_body).to eq({ 'errors' =>
                                                 [{ 'title' => 'Filter not allowed',
                                                    'detail' =>
                                                      '"{"quantity"=>{"eq"=>"8"}}" is not allowed for filtering',
                                                    'code' => '104',
                                                    'status' => '400' }] })
        end
      end
    end

    describe 'sorting parameters' do
      context 'sorts by ASC refill status' do
        let(:params) { { sort: 'refill_status' } }

        it 'sorts prescriptions by ASC refill_status' do
          VCR.use_cassette('rx_client/prescriptions/gets_a_list_of_all_prescriptions_v1') do
            get '/mobile/v0/health/rx/prescriptions', params:, headers: sis_headers
          end

          expect(response).to have_http_status(:ok)
          expect(response.body).to match_json_schema('prescription')
          expect(response.parsed_body['data'].map { |d| d.dig('attributes', 'refillStatus') }).to eq(
            %w[active active activeParked discontinued discontinued discontinued discontinued discontinued discontinued
               discontinued]
          )
        end
      end

      context 'sorts by DESC refill status' do
        let(:params) { { sort: '-refill_status' } }

        it 'sorts prescriptions by DESC refill_status' do
          VCR.use_cassette('rx_client/prescriptions/gets_a_list_of_all_prescriptions_v1') do
            get '/mobile/v0/health/rx/prescriptions', params:, headers: sis_headers
          end

          expect(response).to have_http_status(:ok)
          expect(response.body).to match_json_schema('prescription')
          expect(response.parsed_body['data'].map do |d|
            d.dig('attributes',
                  'refillStatus')
          end).to eq(%w[unknown unknown unknown unknown submitted submitted submitted
                        submitted submitted submitted])
        end
      end

      context 'invalid sort option' do
        let(:params) { { sort: 'quantity' } }

        it 'sorts prescriptions by refill_status', skip: 'not needed with Vets::Collection' do
          VCR.use_cassette('rx_client/prescriptions/gets_a_list_of_all_prescriptions_v1') do
            get '/mobile/v0/health/rx/prescriptions', params:, headers: sis_headers
          end

          expect(response).to have_http_status(:bad_request)
          expect(response.parsed_body).to eq({ 'errors' =>
                                                 [{ 'title' => 'Invalid sort criteria',
                                                    'detail' =>
                                                      '"quantity" is not a valid sort criteria' \
                                                      ' for "PrescriptionDetails"',
                                                    'code' => '106',
                                                    'status' => '400' }] })
        end
      end
    end

    describe 'all parameters' do
      it 'Filters, sorts and paginates prescriptions' do
        params = { 'page' => { number: 2, size: 3 }, 'sort' => '-refill_date',
                   filter: { refill_status: { eq: 'refillinprocess' } } }

        VCR.use_cassette('rx_client/prescriptions/gets_a_list_of_all_prescriptions_v1') do
          get '/mobile/v0/health/rx/prescriptions', params:, headers: sis_headers
        end
        expect(response).to have_http_status(:ok)
        expect(response.body).to match_json_schema('prescription')
        expect(response.parsed_body['meta']['pagination']).to eq({ 'currentPage' => 2,
                                                                   'perPage' => 3,
                                                                   'totalPages' => 5,
                                                                   'totalEntries' => 13 })

        statuses = response.parsed_body['data'].map { |d| d.dig('attributes', 'refillStatus') }.uniq
        expect(statuses).to eq(['refillinprocess'])

        expect(response.parsed_body['data'].map { |p| p.dig('attributes', 'refillDate') }).to eq(
          %w[
            2025-04-11T04:00:00.000Z 2025-04-10T04:00:00.000Z 2025-04-10T04:00:00.000Z
          ]
        )
      end
    end

    describe 'counting subscription statuses' do
      it 'returns meta with a count of all statuses while grouping certain ones under active' do
        VCR.use_cassette('rx_client/prescriptions/gets_a_list_of_all_prescriptions_v1') do
          get '/mobile/v0/health/rx/prescriptions', headers: sis_headers
        end
        expect(response.parsed_body['meta']['prescriptionStatusCount']).to eq({
                                                                                'active' => 27,
                                                                                'discontinued' => 82,
                                                                                'expired' => 22,
                                                                                'unknown' => 4,
                                                                                'renew' => 4,
                                                                                'newOrder' => 7
                                                                              })
      end
    end

    context 'when non va medications are present' do
      it 'sets the has_non_va_meds flag to true' do
        VCR.use_cassette('rx_client/prescriptions/gets_a_list_of_all_prescriptions_v1') do
          get '/mobile/v0/health/rx/prescriptions', headers: sis_headers
        end
        expect(response.parsed_body['meta']['hasNonVaMeds']).to be(true)
      end
    end

    context 'when non va medications are not present' do
      it 'sets the has_non_va_meds flag to false' do
        VCR.use_cassette('rx_client/prescriptions/gets_a_list_of_all_prescriptions_filtered_v1') do
          get '/mobile/v0/health/rx/prescriptions', headers: sis_headers
        end
        expect(response.parsed_body['meta']['hasNonVaMeds']).to be(false)
      end
    end
  end

  describe 'GET /mobile/v0/health/rx/prescriptions/:id/tracking', :aggregate_failures do
    context 'when id is found' do
      it 'returns 200' do
        VCR.use_cassette('mobile/rx_refill/prescriptions/gets_tracking_for_a_prescription') do
          get '/mobile/v0/health/rx/prescriptions/13650541/tracking', headers: sis_headers
        end
        expect(response).to have_http_status(:ok)
        expect(response.body).to match_json_schema('prescription_tracking')
      end
    end

    context 'when record is not found' do
      it 'returns 404' do
        VCR.use_cassette('mobile/rx_refill/prescriptions/tracking_error_id') do
          get '/mobile/v0/health/rx/prescriptions/1/tracking', headers: sis_headers
        end

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'with empty otherPrescriptions section' do
      it 'returns 200 with' do
        VCR.use_cassette('mobile/rx_refill/prescriptions/gets_tracking_with_empty_other_prescriptions') do
          get '/mobile/v0/health/rx/prescriptions/13650541/tracking', headers: sis_headers
        end

        expect(response).to have_http_status(:ok)
        expect(response.body).to match_json_schema('prescription_tracking')
        expect(response.parsed_body['data'].map { |p| p.dig('attributes', 'otherPrescriptions') }.uniq).to eq([[]])
      end
    end
  end
end
