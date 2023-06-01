# frozen_string_literal: true

require 'rails_helper'
require 'support/rx_client_helpers'
require 'support/shared_examples_for_mhv'
require_relative '../support/helpers/iam_session_helper'
require_relative '../support/matchers/json_schema_matcher'

RSpec.describe 'health/rx/prescriptions', type: :request do
  include JsonSchemaMatchers
  include Rx::ClientHelpers

  let(:mhv_account_type) { 'Premium' }
  let(:json_body_headers) { { 'Content-Type' => 'application/json', 'Accept' => 'application/json' } }
  let(:upstream_mhv_history_url) { 'https://mhv-api.example.com/mhv-api/patient/v1/prescription/gethistoryrx' }
  let(:set_cache) do
    path = Rails.root.join('modules', 'mobile', 'spec', 'support', 'fixtures', 'prescriptions.json')
    json_data = JSON.parse(File.read(path), symbolize_names: true)

    Common::Collection.fetch(::Prescription, cache_key: '123:gethistoryrx', ttl: 3600) { json_data }
  end

  before do
    allow(Settings.mhv.rx).to receive(:collection_caching_enabled).and_return(true)
    allow_any_instance_of(MHVAccountTypeService).to receive(:mhv_account_type).and_return(mhv_account_type)
    allow(Rx::Client).to receive(:new).and_return(authenticated_client)
    current_user = build(:iam_user, :mhv)

    iam_sign_in(current_user)
  end

  describe 'GET /mobile/v0/health/rx/prescriptions/refill', :aggregate_failures do
    it 'returns all successful refills' do
      VCR.use_cassette('mobile/rx_refill/prescriptions/refills_prescriptions') do
        put '/mobile/v0/health/rx/prescriptions/refill', params: { ids: %w[21530889 21539942] }, headers: iam_headers
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
                                                           headers: iam_headers
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
                                                           headers: iam_headers
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
        put '/mobile/v0/health/rx/prescriptions/refill', params: { ids: '8398465' }, headers: iam_headers
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
                                                           headers: iam_headers
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

    context 'prescription cache is present on refill' do
      it 'flushes prescription cache on refill' do
        set_cache

        VCR.use_cassette('mobile/rx_refill/prescriptions/refills_prescriptions') do
          put '/mobile/v0/health/rx/prescriptions/refill', params: { ids: %w[21530889 21539942] },
                                                           headers: iam_headers
        end

        get '/mobile/v0/health/rx/prescriptions', headers: iam_headers

        assert_requested :get, upstream_mhv_history_url, times: 1
      end
    end
  end

  describe 'GET /mobile/v0/health/rx/prescriptions', :aggregate_failures do
    context 'with a valid MHV response and no failed facilities' do
      it 'returns 200' do
        VCR.use_cassette('mobile/rx_refill/prescriptions/gets_a_list_of_all_prescriptions') do
          get '/mobile/v0/health/rx/prescriptions', headers: iam_headers
        end
        expect(response).to have_http_status(:ok)
        expect(response.body).to match_json_schema('prescription')
      end
    end

    context 'with a valid EVSS response and failed facilities' do
      it 'returns 200 and omits failed facilities' do
        VCR.use_cassette('mobile/rx_refill/prescriptions/handles_failed_stations') do
          get '/mobile/v0/health/rx/prescriptions', headers: iam_headers
        end
        expect(response).to have_http_status(:ok)
        expect(response.body).to match_json_schema('prescription')
      end
    end

    context 'when cache is populated' do
      it 'uses cache instead of service' do
        set_cache

        get '/mobile/v0/health/rx/prescriptions', headers: iam_headers

        assert_requested :get, upstream_mhv_history_url, times: 0
        expect(response).to have_http_status(:ok)
        expect(response.body).to match_json_schema('prescription')
      end
    end

    context 'when user does not have mhv access' do
      it 'returns a 403 forbidden response' do
        unauthorized_user = build(:iam_user)
        iam_sign_in(unauthorized_user)

        VCR.use_cassette('mobile/rx_refill/prescriptions/gets_a_list_of_all_prescriptions') do
          get '/mobile/v0/health/rx/prescriptions', headers: iam_headers
        end
        expect(response).to have_http_status(:forbidden)
        expect(response.parsed_body).to eq({ 'errors' =>
                                               [{ 'title' => 'Forbidden',
                                                  'detail' => 'User does not have access to the requested resource',
                                                  'code' => '403',
                                                  'status' => '403' }] })
      end
    end

    describe 'error cases' do
      it 'converts 400 errors to 409' do
        VCR.use_cassette('mobile/rx_refill/prescriptions/gets_optimistic_locking_error') do
          get '/mobile/v0/health/rx/prescriptions', headers: iam_headers
        end

        expect(response).to have_http_status(:conflict)
      end

      it 'converts Faraday::TimeouError to 408' do
        allow_any_instance_of(Faraday::Connection).to receive(:get).and_raise(Faraday::TimeoutError)

        get '/mobile/v0/health/rx/prescriptions', headers: iam_headers
        expect(response).to have_http_status(:request_timeout)
      end
    end

    describe 'pagination parameters' do
      it 'forms meta data' do
        params = { page: { number: 2, size: 3 } }

        VCR.use_cassette('mobile/rx_refill/prescriptions/gets_a_list_of_all_prescriptions') do
          get '/mobile/v0/health/rx/prescriptions', params:, headers: iam_headers
        end
        expect(response).to have_http_status(:ok)
        expect(response.body).to match_json_schema('prescription')
        expect(response.parsed_body['meta']).to eq({ 'pagination' =>
                                                       { 'currentPage' => 2,
                                                         'perPage' => 3,
                                                         'totalPages' => 20,
                                                         'totalEntries' => 59 } })
      end
    end

    describe 'filtering parameters' do
      context 'filter by refill status' do
        params = { filter: { refill_status: { eq: 'refillinprocess' } } }

        it 'returns all prescriptions that are refillinprocess status' do
          VCR.use_cassette('mobile/rx_refill/prescriptions/gets_a_list_of_all_prescriptions') do
            get '/mobile/v0/health/rx/prescriptions', params:, headers: iam_headers
          end
          expect(response).to have_http_status(:ok)
          expect(response.body).to match_json_schema('prescription')

          refill_statuses = response.parsed_body['data'].map { |d| d.dig('attributes', 'refillStatus') }.uniq
          expect(refill_statuses).to eq(['refillinprocess'])
        end
      end

      context 'filter by multiple fields' do
        params = { filter: { is_refillable: { eq: 'true' }, is_trackable: { eq: 'true' } } }

        it 'returns all prescriptions that are both trackable and refillable' do
          VCR.use_cassette('mobile/rx_refill/prescriptions/gets_a_list_of_all_prescriptions') do
            get '/mobile/v0/health/rx/prescriptions', params:, headers: iam_headers
          end
          expect(response).to have_http_status(:ok)
          expect(response.body).to match_json_schema('prescription')
          expect(response.parsed_body['data'].size).to eq(1)
          expect(response.parsed_body.dig('data', 0, 'attributes', 'isTrackable')).to eq(true)
          expect(response.parsed_body.dig('data', 0, 'attributes', 'isRefillable')).to eq(true)
        end
      end

      context 'filter by multiple types of refill_statuses' do
        let(:params) do
          { page: { number: 1, size: 100 }, filter: { refill_status: { eq: 'refillinprocess,active' } } }
        end

        it 'returns all prescriptions that are both trackable and refillable' do
          VCR.use_cassette('mobile/rx_refill/prescriptions/gets_a_list_of_all_prescriptions') do
            get '/mobile/v0/health/rx/prescriptions', params:, headers: iam_headers
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
          VCR.use_cassette('mobile/rx_refill/prescriptions/gets_a_list_of_all_prescriptions') do
            get '/mobile/v0/health/rx/prescriptions', params:, headers: iam_headers
          end
          expect(response).to have_http_status(:ok)
          expect(response.body).to match_json_schema('prescription')

          refill_statuses = response.parsed_body['data'].map { |d| d.dig('attributes', 'refillStatus') }.uniq

          # does not include refillinprocess
          expect(refill_statuses).to eq(%w[discontinued transferred expired activeParked active submitted hold unknown])
        end
      end

      context 'invalid filter option' do
        params = { filter: { quantity: { eq: '8' } } }

        it 'cannot filter by unexpected field' do
          VCR.use_cassette('mobile/rx_refill/prescriptions/gets_a_list_of_all_prescriptions') do
            get '/mobile/v0/health/rx/prescriptions', params:, headers: iam_headers
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
          VCR.use_cassette('mobile/rx_refill/prescriptions/gets_a_list_of_all_prescriptions') do
            get '/mobile/v0/health/rx/prescriptions', params:, headers: iam_headers
          end

          expect(response).to have_http_status(:ok)
          expect(response.body).to match_json_schema('prescription')
          expect(response.parsed_body['data'].map { |d| d.dig('attributes', 'refillStatus') }).to eq(
            %w[active active active active activeParked activeParked activeParked activeParked discontinued
               discontinued]
          )
        end
      end

      context 'sorts by DESC refill status' do
        let(:params) { { sort: '-refill_status' } }

        it 'sorts prescriptions by DESC refill_status' do
          VCR.use_cassette('mobile/rx_refill/prescriptions/gets_a_list_of_all_prescriptions') do
            get '/mobile/v0/health/rx/prescriptions', params:, headers: iam_headers
          end

          expect(response).to have_http_status(:ok)
          expect(response.body).to match_json_schema('prescription')
          expect(response.parsed_body['data'].map do |d|
            d.dig('attributes',
                  'refillStatus')
          end).to eq(%w[unknown transferred submitted submitted submitted submitted refillinprocess
                        refillinprocess refillinprocess refillinprocess])
        end
      end

      context 'invalid sort option' do
        let(:params) { { sort: 'quantity' } }

        it 'sorts prescriptions by refill_status' do
          VCR.use_cassette('mobile/rx_refill/prescriptions/gets_a_list_of_all_prescriptions') do
            get '/mobile/v0/health/rx/prescriptions', params:, headers: iam_headers
          end

          expect(response).to have_http_status(:bad_request)
          expect(response.parsed_body).to eq({ 'errors' =>
                                                 [{ 'title' => 'Invalid sort criteria',
                                                    'detail' =>
                                                      '"quantity" is not a valid sort criteria for "Prescription"',
                                                    'code' => '106',
                                                    'status' => '400' }] })
        end
      end
    end

    describe 'all parameters' do
      it 'Filters, sorts and paginates prescriptions' do
        params = { 'page' => { number: 2, size: 3 }, 'sort' => '-refill_date',
                   filter: { refill_status: { eq: 'refillinprocess' } } }

        VCR.use_cassette('mobile/rx_refill/prescriptions/gets_a_list_of_all_prescriptions') do
          get '/mobile/v0/health/rx/prescriptions', params:, headers: iam_headers
        end
        expect(response).to have_http_status(:ok)
        expect(response.body).to match_json_schema('prescription')
        expect(response.parsed_body['meta']).to eq({ 'pagination' =>
                                                       { 'currentPage' => 2,
                                                         'perPage' => 3,
                                                         'totalPages' => 12,
                                                         'totalEntries' => 36 } })

        statuses = response.parsed_body['data'].map { |d| d.dig('attributes', 'refillStatus') }.uniq
        expect(statuses).to eq(['refillinprocess'])

        expect(response.parsed_body['data'].map { |p| p.dig('attributes', 'refillDate') }).to eq(
          %w[
            2021-12-07T05:00:00.000Z 2021-10-27T04:00:00.000Z 2021-10-22T04:00:00.000Z
          ]
        )
      end
    end
  end

  describe 'GET /mobile/v0/health/rx/prescriptions/:id/tracking', :aggregate_failures do
    context 'when id is found' do
      it 'returns 200' do
        VCR.use_cassette('mobile/rx_refill/prescriptions/gets_tracking_for_a_prescription') do
          get '/mobile/v0/health/rx/prescriptions/13650541/tracking', headers: iam_headers
        end
        expect(response).to have_http_status(:ok)
        expect(response.body).to match_json_schema('prescription_tracking')
      end
    end

    context 'when record is not found' do
      it 'returns 404' do
        VCR.use_cassette('mobile/rx_refill/prescriptions/tracking_error_id') do
          get '/mobile/v0/health/rx/prescriptions/1/tracking', headers: iam_headers
        end

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'with empty otherPrescriptions section' do
      it 'returns 200 with ' do
        VCR.use_cassette('mobile/rx_refill/prescriptions/gets_tracking_with_empty_other_prescriptions') do
          get '/mobile/v0/health/rx/prescriptions/13650541/tracking', headers: iam_headers
        end

        expect(response).to have_http_status(:ok)
        expect(response.body).to match_json_schema('prescription_tracking')
        expect(response.parsed_body['data'].map { |p| p.dig('attributes', 'otherPrescriptions') }.uniq).to eq([[]])
      end
    end
  end
end
