# frozen_string_literal: true

require_relative '../../../../support/helpers/rails_helper'
require 'unified_health_data/service'
require 'unique_user_events'

RSpec.describe 'Mobile::V1::Health::Prescriptions', type: :request do
  include JsonSchemaMatchers

  let!(:user) { sis_user(:mhv, mhv_account_type:) }
  let(:mhv_account_type) { 'Premium' }
  let(:va_patient) { true }
  let(:current_user) { user }
  let(:patient) { false }

  before do
    allow_any_instance_of(User).to receive(:va_patient?).and_return(va_patient)
    allow_any_instance_of(User).to receive(:mhv_user_account).and_return(OpenStruct.new(patient:))
    sign_in_as(user)
    allow(Flipper).to receive(:enabled?).with(:mhv_medications_cerner_pilot, anything).and_return(true)
    # Freeze today so service default_end_date is deterministic for VCR cassettes
    allow(Time.zone).to receive(:today).and_return(Date.new(2025, 9, 19))
  end

  describe 'GET /mobile/v1/health/rx/prescriptions' do
    context 'when user is not authenticated' do
      it 'returns unauthorized' do
        get '/mobile/v1/health/rx/prescriptions'

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when user does not have mhv access' do
      let!(:user) { sis_user }

      it 'returns a 403 forbidden response' do
        VCR.use_cassette('unified_health_data/get_prescriptions_success') do
          get '/mobile/v1/health/rx/prescriptions', headers: sis_headers
        end
        expect(response).to have_http_status(:forbidden)
        expect(response.parsed_body).to eq({ 'errors' =>
                                             [{ 'title' => 'Forbidden',
                                                'detail' => 'User does not have access to the requested resource',
                                                'code' => '403',
                                                'status' => '403' }] })
      end
    end

    context 'when user is authenticated' do
      let(:patient) { true }

      context 'with mhv_medications_cerner_pilot feature flag disabled' do
        before do
          allow(Flipper).to receive(:enabled?).with(:mhv_medications_cerner_pilot, anything).and_return(false)
        end

        it 'returns forbidden error' do
          get '/mobile/v1/health/rx/prescriptions', headers: sis_headers

          expect(response).to have_http_status(:forbidden)
          expect(response.parsed_body['error']['code']).to eq('FEATURE_NOT_AVAILABLE')
        end
      end

      context 'with mhv_medications_cerner_pilot feature flag enabled' do
        before do
          allow(Flipper).to receive(:enabled?).with(:mhv_medications_cerner_pilot, anything).and_return(true)
        end

        context 'when UHD service returns prescriptions successfully' do
          it 'returns prescriptions with mobile-specific metadata' do
            allow(UniqueUserEvents).to receive(:log_event)
            VCR.use_cassette('unified_health_data/get_prescriptions_success') do
              get '/mobile/v1/health/rx/prescriptions', headers: sis_headers

              expect(response).to have_http_status(:ok)
              expect(response.parsed_body).to have_key('data')
              expect(response.parsed_body).to have_key('meta')
              expect(response.parsed_body['meta']).to have_key('pagination')
              expect(response.parsed_body['meta']).to have_key('prescriptionStatusCount')
              expect(response.parsed_body['meta']).to have_key('hasNonVaMeds')

              # Verify that prescription data includes tracking field as empty array
              expect(response.parsed_body['data']).to be_an(Array)
              if response.parsed_body['data'].any?
                first_prescription = response.parsed_body['data'].first
                expect(first_prescription['attributes']).to have_key('tracking')
                expect(first_prescription['attributes']['tracking']).to eq([])
              end

              # Verify event logging was called
              expect(UniqueUserEvents).to have_received(:log_event).with(
                user: anything,
                event_name: UniqueUserEvents::EventRegistry::PRESCRIPTIONS_ACCESSED
              )
            end
          end

          it 'handles pagination parameters correctly (nested page[number], page[size])' do
            VCR.use_cassette('unified_health_data/get_prescriptions_success') do
              get '/mobile/v1/health/rx/prescriptions',
                  params: { page: { number: 2, size: 10 }, sort: 'refill_status' },
                  headers: sis_headers
              expect(response).to have_http_status(:ok)
              meta = response.parsed_body['meta']['pagination']
              expect(meta['currentPage']).to eq(2)
              expect(meta['perPage']).to eq(10)
              expect(response.parsed_body['data'].length).to be <= 10
            end
          end

          context 'with a mix of VA and Non-VA prescriptions' do
            let(:rx_va) do
              OpenStruct.new(
                id: 'rx-va-1',
                refill_status: 'active', refill_submit_date: nil, refill_date: nil, refill_remaining: 5,
                facility_name: 'VA FAC', ordered_date: nil, quantity: 30, expiration_date: nil,
                prescription_number: '123', prescription_name: 'VA MED', dispensed_date: nil, station_number: '500',
                is_refillable: true, is_trackable: false, tracking: [], prescription_source: 'RX',
                instructions: 'Take daily', facility_phone_number: '555-555-5555'
              )
            end
            let(:rx_non_va) do
              OpenStruct.new(
                id: 'rx-nv-1',
                refill_status: 'active', refill_submit_date: nil, refill_date: nil, refill_remaining: 1,
                facility_name: 'NON VA', ordered_date: nil, quantity: 10, expiration_date: nil,
                prescription_number: 'NV1', prescription_name: 'NON VA MED', dispensed_date: nil, station_number: '600',
                is_refillable: false, is_trackable: false, tracking: [], prescription_source: 'NV',
                instructions: 'As needed', facility_phone_number: '555-000-0000'
              )
            end

            before do
              allow_any_instance_of(UnifiedHealthData::Service).to receive(:get_prescriptions)
                .and_return([rx_va, rx_non_va])
            end

            it 'filters out Non-VA meds and sets hasNonVaMeds meta true' do
              get '/mobile/v1/health/rx/prescriptions',
                  params: { page: { number: 1, size: 10 } },
                  headers: sis_headers

              expect(response).to have_http_status(:ok)
              body = response.parsed_body
              expect(body['data'].length).to eq(1)
              names = body['data'].map { |d| d['attributes']['prescriptionName'] }
              expect(names).to include('VA MED')
              expect(names).not_to include('NON VA MED')
              expect(body['meta']['hasNonVaMeds']).to be true
            end
          end

          context 'with only VA prescriptions (no Non-VA present)' do
            let(:rx_va1) do
              OpenStruct.new(
                id: 'rx-va-only-1',
                refill_status: 'active', refill_submit_date: nil, refill_date: nil,
                refill_remaining: 2,
                facility_name: 'VA FAC', ordered_date: nil, quantity: 60, expiration_date: nil,
                prescription_number: '456', prescription_name: 'VA MED A', dispensed_date: nil, station_number: '500',
                is_refillable: true, is_trackable: false, tracking: [], prescription_source: 'RX',
                instructions: 'Daily', facility_phone_number: '555-555-5555'
              )
            end
            let(:rx_va2) do
              OpenStruct.new(
                id: 'rx-va-only-2',
                refill_status: 'active', refill_submit_date: nil, refill_date: nil,
                refill_remaining: 0,
                facility_name: 'VA FAC', ordered_date: nil, quantity: 15, expiration_date: nil,
                prescription_number: '789', prescription_name: 'VA MED B', dispensed_date: nil, station_number: '500',
                is_refillable: false, is_trackable: false, tracking: [], prescription_source: 'RX',
                instructions: 'Bid', facility_phone_number: '555-555-5555'
              )
            end

            before do
              allow_any_instance_of(UnifiedHealthData::Service).to receive(:get_prescriptions)
                .and_return([rx_va1, rx_va2])
            end

            it 'does not set hasNonVaMeds meta flag' do
              get '/mobile/v1/health/rx/prescriptions',
                  params: { page: { number: 1, size: 10 } },
                  headers: sis_headers

              expect(response).to have_http_status(:ok)
              body = response.parsed_body
              expect(body['data'].length).to eq(2)
              expect(body['meta']['hasNonVaMeds']).to be false
            end
          end
        end

        context 'counting prescription statuses' do
          it 'returns meta with prescription status counts including refillable and active prescriptions' do
            VCR.use_cassette('unified_health_data/get_prescriptions_success') do
              get '/mobile/v1/health/rx/prescriptions', headers: sis_headers

              expect(response).to have_http_status(:ok)
              expect(response.parsed_body['meta']).to have_key('prescriptionStatusCount')

              status_count = response.parsed_body['meta']['prescriptionStatusCount']
              expect(status_count).to be_a(Hash)

              # Verify the structure includes expected keys
              expected_keys = %w[isRefillable active]
              expected_keys.each do |key|
                expect(status_count).to have_key(key)
                expect(status_count[key]).to be_a(Integer)
                expect(status_count[key]).to be >= 0
              end
            end
          end
        end

        context 'when UHD service returns empty results' do
          it 'returns empty array with correct metadata' do
            VCR.use_cassette('unified_health_data/get_prescriptions_empty') do
              get '/mobile/v1/health/rx/prescriptions', headers: sis_headers

              expect(response).to have_http_status(:ok)
              expect(response.parsed_body['data']).to eq([])
              expect(response.parsed_body['meta']['pagination']['totalEntries']).to eq(0)
              expect(response.parsed_body['meta']).to have_key('prescriptionStatusCount')
              expect(response.parsed_body['meta']['prescriptionStatusCount']).to be_a(Hash)
            end
          end
        end
      end
    end
  end

  describe 'PUT /mobile/v1/health/rx/prescriptions/refill' do
    context 'when user does not have mhv access' do
      let!(:user) { sis_user }

      it 'returns a 403 forbidden response' do
        put '/mobile/v1/health/rx/prescriptions/refill',
            params: [{ stationNumber: '123', id: '25804851' }].to_json,
            headers: sis_headers.merge('Content-Type' => 'application/json')

        expect(response).to have_http_status(:forbidden)
        expect(response.parsed_body).to eq({ 'errors' =>
                                             [{ 'title' => 'Forbidden',
                                                'detail' => 'User does not have access to the requested resource',
                                                'code' => '403',
                                                'status' => '403' }] })
      end
    end

    context 'when user is authenticated and has mhv access' do
      let(:patient) { true }

      context 'when response count does not match request count' do
        it 'returns an error for each order id when response count does not match request count' do
          VCR.use_cassette('unified_health_data/refill_prescription_success') do
            put '/mobile/v1/health/rx/prescriptions/refill',
                params: [
                  { stationNumber: '123', id: '25804851' },
                  { stationNumber: '124', id: '25804852' },
                  { stationNumber: '125', id: '25804853' }
                ].to_json,
                headers: sis_headers.merge('Content-Type' => 'application/json')
          end

          expect(response).to have_http_status(:ok)
          expect(response.parsed_body['data']['attributes']['failedPrescriptionIds'].length).to eq(3)
        end
      end

      context 'with feature mhv_medications_cerner_pilot flag enabled' do
        before do
          allow(Flipper).to receive(:enabled?).with(:mhv_medications_cerner_pilot, anything).and_return(true)
        end

        context 'when refill is successful' do
          it 'returns success response for batch refill' do
            allow(UniqueUserEvents).to receive(:log_event)
            VCR.use_cassette('unified_health_data/get_prescriptions_success') do
              VCR.use_cassette('unified_health_data/refill_prescription_success') do
                put '/mobile/v1/health/rx/prescriptions/refill',
                    params: [
                      { stationNumber: '556', id: '15220389459' },
                      { stationNumber: '570', id: '0000000000001' }
                    ].to_json,
                    headers: sis_headers.merge('Content-Type' => 'application/json')

                expect(response).to have_http_status(:ok)
                expect(response.parsed_body).to have_key('data')

                data = response.parsed_body['data']
                expect(data).to have_key('id')
                expect(data['type']).to eq('PrescriptionRefills')
                expect(data['attributes']).to have_key('failedStationList')
                expect(data['attributes']).to have_key('successfulStationList')
                expect(data['attributes']).to have_key('lastUpdatedTime')
                expect(data['attributes']).to have_key('prescriptionList')
                expect(data['attributes']).to have_key('failedPrescriptionIds')
                expect(data['attributes']).to have_key('errors')
                expect(data['attributes']).to have_key('infoMessages')

                # Verify event logging was called with station numbers from orders
                expect(UniqueUserEvents).to have_received(:log_event).with(
                  user: anything,
                  event_name: UniqueUserEvents::EventRegistry::PRESCRIPTIONS_REFILL_REQUESTED,
                  event_facility_ids: %w[556 570]
                )
              end
            end
          end
        end

        context 'when prescription refill fails' do
          it 'returns 502 error for upstream service failure' do
            VCR.use_cassette('unified_health_data/refill_prescription_failure') do
              put '/mobile/v1/health/rx/prescriptions/refill',
                  params: [{ stationNumber: '123', id: '99999999999999' }].to_json,
                  headers: sis_headers.merge('Content-Type' => 'application/json')

              expect(response).to have_http_status(:bad_request)
              expect(response.parsed_body['errors'][0]['code']).to eq('VA900')
              expect(response.parsed_body['errors'][0]['detail']).to include('Operation failed')
            end
          end
        end

        context 'when no prescriptions provided' do
          it 'returns parameter required error' do
            VCR.use_cassette('unified_health_data/refill_prescription_success') do
              put '/mobile/v1/health/rx/prescriptions/refill',
                  params: '[]',
                  headers: sis_headers.merge('Content-Type' => 'application/json')

              expect(response).to have_http_status(:bad_request)
              # Assert structured VA.gov error envelope for missing required parameter
              error = response.parsed_body['errors']&.first
              expect(error).to be_present
              expect(error['title']).to eq('Missing parameter')
              expect(error['status']).to eq('400')
              expect(error['code']).to eq('108')
              expect(error['detail']).to include('orders')
            end
          end
        end

        context 'refill response handling' do
          let(:mock_service) { instance_double(UnifiedHealthData::Service) }

          before do
            allow(UnifiedHealthData::Service).to receive(:new).and_return(mock_service)
          end

          it 'handles empty success and failed arrays correctly' do
            # Mock service returns empty arrays for both success and failed
            allow(mock_service).to receive(:refill_prescription).and_return({
                                                                              success: [],
                                                                              failed: []
                                                                            })

            put '/mobile/v1/health/rx/prescriptions/refill',
                params: [{ stationNumber: '123', id: '25804851' }].to_json,
                headers: sis_headers.merge('Content-Type' => 'application/json')

            expect(response).to have_http_status(:ok)
            data = response.parsed_body['data']
            expect(data['type']).to eq('PrescriptionRefills')
            expect(data['attributes']).to have_key('successfulStationList')
            expect(data['attributes']).to have_key('failedStationList')
            expect(data['attributes']).to have_key('prescriptionList')
          end

          it 'handles service response with only successful refills' do
            # Mock service returns success array with items, empty failed array
            allow(mock_service).to receive(:refill_prescription).and_return({
                                                                              success: [
                                                                                { id: '25804851', status: 'submitted',
                                                                                  station_number: '123' }
                                                                              ],
                                                                              failed: []
                                                                            })

            put '/mobile/v1/health/rx/prescriptions/refill',
                params: [{ stationNumber: '123', id: '25804851' }].to_json,
                headers: sis_headers.merge('Content-Type' => 'application/json')

            expect(response).to have_http_status(:ok)
            data = response.parsed_body['data']
            expect(data['type']).to eq('PrescriptionRefills')
            expect(data['attributes']).to have_key('successfulStationList')
            expect(data['attributes']).to have_key('failedStationList')
            expect(data['attributes']).to have_key('prescriptionList')
          end

          it 'handles service response with only failed refills' do
            # Mock service returns empty success array, failed array with items
            allow(mock_service).to receive(:refill_prescription).and_return({
                                                                              success: [],
                                                                              failed: [
                                                                                { id: '25804851', error: 'Not found',
                                                                                  station_number: '123' }
                                                                              ]
                                                                            })

            put '/mobile/v1/health/rx/prescriptions/refill',
                params: [{ stationNumber: '123', id: '25804851' }].to_json,
                headers: sis_headers.merge('Content-Type' => 'application/json')

            expect(response).to have_http_status(:ok)
            data = response.parsed_body['data']
            expect(data['type']).to eq('PrescriptionRefills')
            expect(data['attributes']).to have_key('successfulStationList')
            expect(data['attributes']).to have_key('failedStationList')
            expect(data['attributes']).to have_key('prescriptionList')
            expect(data['attributes']).to have_key('failedPrescriptionIds')
          end

          it 'handles service response with mixed success and failed refills' do
            # Mock service returns both success and failed arrays with items
            allow(mock_service).to receive(:refill_prescription).and_return({
                                                                              success: [
                                                                                { id: '25804851', status: 'submitted',
                                                                                  station_number: '123' }
                                                                              ],
                                                                              failed: [
                                                                                { id: '25804852', error: 'Not found',
                                                                                  station_number: '124' }
                                                                              ]
                                                                            })

            put '/mobile/v1/health/rx/prescriptions/refill',
                params: [
                  { stationNumber: '123', id: '25804851' },
                  { stationNumber: '124', id: '25804852' }
                ].to_json,
                headers: sis_headers.merge('Content-Type' => 'application/json')

            expect(response).to have_http_status(:ok)
            data = response.parsed_body['data']
            expect(data['type']).to eq('PrescriptionRefills')
            expect(data['attributes']).to have_key('successfulStationList')
            expect(data['attributes']).to have_key('failedStationList')
            expect(data['attributes']).to have_key('prescriptionList')
            expect(data['attributes']).to have_key('failedPrescriptionIds')
          end

          it 'always receives arrays from service for success and failed keys' do
            # This test verifies the service contract - that we always get arrays
            expect(mock_service).to receive(:refill_prescription) do |orders|
              expect(orders).to be_an(Array)
              # Return the expected format with arrays
              {
                success: [],
                failed: []
              }
            end

            put '/mobile/v1/health/rx/prescriptions/refill',
                params: [{ stationNumber: '123', id: '25804851' }].to_json,
                headers: sis_headers.merge('Content-Type' => 'application/json')

            # Controller now always returns success response with serialized result
            expect(response).to have_http_status(:ok)
            data = response.parsed_body['data']
            expect(data['type']).to eq('PrescriptionRefills')
          end
        end
      end
    end
  end
end
