# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'VAOS V2 Referrals', type: :request do
  describe 'GET /vaos/v2/referrals' do
    let(:memory_store) { ActiveSupport::Cache.lookup_store(:memory_store) }
    let(:icn) { '1012845331V153043' }
    let(:user) { build(:user, :vaos, :loa3, icn:) }
    let(:referrals) { build_list(:ccra_referral_list_entry, 3) }
    let(:service_double) { instance_double(Ccra::ReferralService) }

    before do
      allow(Rails).to receive(:cache).and_return(memory_store)
      Rails.cache.clear

      allow(Ccra::ReferralService).to receive(:new).and_return(service_double)
      allow(service_double).to receive(:get_vaos_referral_list).and_return(referrals)

      # Mock the encryption service for each referral in the list
      referrals.each do |ref|
        allow(VAOS::ReferralEncryptionService).to receive(:encrypt)
          .with(ref.referral_consult_id)
          .and_return("encrypted-#{ref.referral_consult_id}")
      end
    end

    context 'when user is not authenticated' do
      it 'returns 401 unauthorized' do
        get '/vaos/v2/referrals'

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when user is authenticated' do
      before do
        sign_in_as(user)
      end

      it 'returns referrals list in JSON:API format' do
        get '/vaos/v2/referrals'

        expect(response).to have_http_status(:ok)
        response_data = JSON.parse(response.body)

        expect(response_data).to have_key('data')
        expect(response_data['data']).to be_an(Array)
        expect(response_data['data'].length).to eq(3)

        first_referral = response_data['data'].first
        expect(first_referral).to have_key('id')
        expect(first_referral).to have_key('type')
        expect(first_referral).to have_key('attributes')
        expect(first_referral['attributes']).to have_key('categoryOfCare')
        expect(first_referral['attributes']).to have_key('referralNumber')
      end
    end

    context 'when a configuration error occurs' do
      # Note we only test this once as the code is the same for both endpoints
      let(:jwt_error) { Common::JwtWrapper::ConfigurationError.new('Configuration error occurred') }
      let(:config_error) { VAOS::Exceptions::ConfigurationError.new(jwt_error, 'CCRA') }

      before do
        sign_in_as(user)
        allow(service_double).to receive(:get_vaos_referral_list).and_raise(config_error)
      end

      it 'returns 503 Service Unavailable with properly formatted error response' do
        get '/vaos/v2/referrals'

        expect(response).to have_http_status(:service_unavailable)

        response_data = JSON.parse(response.body)

        expect(response_data).to have_key('errors')
        expect(response_data['errors']).to be_an(Array)
        expect(response_data['errors'].first).to include(
          'title' => 'Service Configuration Error',
          'detail' => 'The CCRA service is unavailable due to a configuration issue',
          'code' => 'VAOS_CONFIG_ERROR',
          'status' => '503'
        )
      end

      it 'does not expose internal error details' do
        get '/vaos/v2/referrals'

        response_data = JSON.parse(response.body)

        # Original error message is not leaked
        expect(response_data['errors'].first['detail']).not_to include('Configuration error occurred')

        # No stack trace is included
        expect(response_data['errors'].first).not_to have_key('meta')
        expect(response_data['errors'].first).not_to have_key('backtrace')
      end
    end
  end

  describe 'GET /vaos/v2/referrals/:id' do
    let(:memory_store) { ActiveSupport::Cache.lookup_store(:memory_store) }
    let(:icn) { '1012845331V153043' }
    let(:referral_number) { '5682' }
    let(:encrypted_uuid) { 'encrypted-5682' }
    let(:user) { build(:user, :vaos, :loa3, icn:) }
    let(:referral) { build(:ccra_referral_detail, referral_number:) }
    let(:service_double) { instance_double(Ccra::ReferralService) }

    before do
      allow(Rails).to receive(:cache).and_return(memory_store)
      Rails.cache.clear

      allow(Ccra::ReferralService).to receive(:new).and_return(service_double)
      allow(service_double).to receive(:get_referral).with(referral_number, icn).and_return(referral)
      allow(VAOS::ReferralEncryptionService).to receive(:encrypt).with(referral_number).and_return(encrypted_uuid)
      allow(VAOS::ReferralEncryptionService).to receive(:decrypt).with(encrypted_uuid).and_return(referral_number)
      allow(VAOS::ReferralEncryptionService)
        .to receive(:decrypt)
        .with('invalid')
        .and_raise(Common::Exceptions::ParameterMissing.new('id'))
    end

    context 'when user is not authenticated' do
      it 'returns 401 unauthorized' do
        get "/vaos/v2/referrals/#{encrypted_uuid}"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when user is authenticated' do
      before do
        sign_in_as(user)
      end

      it 'returns referral detail in JSON:API format' do
        allow_any_instance_of(VAOS::V2::AppointmentsService).to receive(:get_active_appointments_for_referral)
          .and_return({
                        EPS: { data: [] },
                        VAOS: { data: [] }
                      })

        get "/vaos/v2/referrals/#{encrypted_uuid}"

        expect(response).to have_http_status(:ok)
        response_data = JSON.parse(response.body)

        expect(response_data).to have_key('data')
        expect(response_data['data']).to have_key('id')
        expect(response_data['data']['id']).to eq(encrypted_uuid)
        expect(response_data['data']).to have_key('type')
        expect(response_data['data']['type']).to eq('referrals')
        expect(response_data['data']).to have_key('attributes')
        expect(response_data['data']['attributes']).to have_key('categoryOfCare')

        # Check nested provider attributes
        expect(response_data['data']['attributes']).to have_key('provider')
        provider = response_data['data']['attributes']['provider']
        expect(provider).to be_a(Hash)
        expect(provider).to have_key('name')
        expect(provider).to have_key('npi')
        expect(provider).to have_key('phone')
        # Address may or may not be present depending on the data

        # Check referring facility attributes
        if response_data['data']['attributes'].key?('referringFacility')
          facility = response_data['data']['attributes']['referringFacility']
          expect(facility).to be_a(Hash)
          expect(facility).to have_key('name')
          expect(facility).to have_key('code')
          expect(facility).to have_key('phone')
        end

        expect(response_data['data']['attributes']).to have_key('referralNumber')
        expect(response_data['data']['attributes']).to have_key('hasAppointments')
        expect(response_data['data']['attributes']).to have_key('appointments')
      end

      it 'increments the view metric' do
        allow_any_instance_of(VAOS::V2::AppointmentsService).to receive(:get_active_appointments_for_referral)
          .and_return({
                        EPS: { data: [] },
                        VAOS: { data: [] }
                      })

        expect(StatsD).to receive(:increment)
          .with(VAOS::V2::ReferralsController::REFERRAL_DETAIL_VIEW_METRIC,
                tags: [
                  'service:community_care_appointments',
                  'referring_facility_code:552',
                  'station_id:528A6',
                  'type_of_care:CARDIOLOGY'
                ])
          .once

        allow(StatsD).to receive(:increment)

        get "/vaos/v2/referrals/#{encrypted_uuid}"
      end

      context 'when fetching appointments' do
        it 'includes appointments from both sources when available' do
          allow_any_instance_of(VAOS::V2::AppointmentsService).to receive(:get_active_appointments_for_referral)
            .and_return({
                          EPS: {
                            data: [
                              { id: '12345', status: 'active', start: '2024-11-21T18:00:00Z' }
                            ]
                          },
                          VAOS: {
                            data: [
                              { id: '56789', status: 'cancelled', start: '2024-11-21T18:00:00Z' }
                            ]
                          }
                        })

          get "/vaos/v2/referrals/#{encrypted_uuid}"

          expect(response).to have_http_status(:ok)
          response_data = JSON.parse(response.body)

          expect(response_data['data']['attributes']).to have_key('appointments')
          appointments = response_data['data']['attributes']['appointments']

          expect(appointments).to have_key('EPS')
          expect(appointments).to have_key('VAOS')
          expect(appointments['EPS']['data']).to be_an(Array)
          expect(appointments['VAOS']['data']).to be_an(Array)
          expect(appointments['EPS']['data'].first['id']).to eq('12345')
          expect(appointments['VAOS']['data'].first['id']).to eq('56789')

          # Check has_appointments attribute
          expect(response_data['data']['attributes']).to have_key('hasAppointments')
          expect(response_data['data']['attributes']['hasAppointments']).to be(true)
        end

        it 'returns empty data when no appointments found' do
          allow_any_instance_of(VAOS::V2::AppointmentsService).to receive(:get_active_appointments_for_referral)
            .and_return({
                          EPS: { data: [] },
                          VAOS: { data: [] }
                        })

          get "/vaos/v2/referrals/#{encrypted_uuid}"

          expect(response).to have_http_status(:ok)
          response_data = JSON.parse(response.body)

          expect(response_data['data']['attributes']).to have_key('appointments')
          appointments = response_data['data']['attributes']['appointments']
          expect(appointments['EPS']['data']).to eq([])
          expect(appointments['VAOS']['data']).to eq([])

          # Check has_appointments attribute when no appointments
          expect(response_data['data']['attributes']).to have_key('hasAppointments')
          expect(response_data['data']['attributes']['hasAppointments']).to be(false)
        end

        it 'returns error response when appointment service raises BackendServiceException' do
          allow_any_instance_of(VAOS::V2::AppointmentsService).to receive(:get_active_appointments_for_referral)
            .and_raise(Common::Exceptions::BackendServiceException.new('VAOS_502', { source: 'EPS' }))

          get "/vaos/v2/referrals/#{encrypted_uuid}"

          expect(response).to have_http_status(:bad_gateway)
          response_data = JSON.parse(response.body)

          expect(response_data).to have_key('errors')
          expect(response_data['errors']).to be_an(Array)
          expect(response_data['errors'].first).to include('code' => 'VAOS_502')
        end
      end

      context 'when provider IDs are missing' do
        shared_examples 'logs missing provider ID error' do |facility_code, npi, expected_missing_fields|
          let(:test_station_id) { '646' }

          before do
            test_referral = build(:ccra_referral_detail, referral_number:,
                                                         referring_facility_code: facility_code,
                                                         provider_npi: npi,
                                                         station_id: test_station_id)
            allow(service_double).to receive(:get_referral)
              .with(referral_number, icn).and_return(test_referral)
          end

          it 'logs the appropriate error message with station_id' do
            allow_any_instance_of(VAOS::V2::AppointmentsService).to receive(:get_active_appointments_for_referral)
              .and_return({
                            EPS: { data: [] },
                            VAOS: { data: [] }
                          })

            expect(Rails.logger).to receive(:error)
              .with('Community Care Appointments: Referral detail view: Missing provider data', {
                      missing_data: expected_missing_fields,
                      station_id: test_station_id,
                      user_uuid: user.uuid
                    })
            get "/vaos/v2/referrals/#{encrypted_uuid}"
          end
        end

        context 'when both IDs are missing' do
          include_examples 'logs missing provider ID error', nil, '', [
            VAOS::V2::ReferralsController::REFERRING_FACILITY_CODE_FIELD,
            VAOS::V2::ReferralsController::REFERRAL_PROVIDER_NPI_FIELD
          ]
        end

        context 'when referring provider ID is missing' do
          include_examples 'logs missing provider ID error', '', '1234567890', [
            VAOS::V2::ReferralsController::REFERRING_FACILITY_CODE_FIELD
          ]
        end

        context 'when referral provider ID is missing' do
          include_examples 'logs missing provider ID error', '552', nil, [
            VAOS::V2::ReferralsController::REFERRAL_PROVIDER_NPI_FIELD
          ]
        end

        context 'when station_id is blank' do
          before do
            test_referral = build(:ccra_referral_detail, referral_number:,
                                                         referring_facility_code: nil,
                                                         provider_npi: '1234567890',
                                                         station_id: '')
            allow(service_double).to receive(:get_referral)
              .with(referral_number, icn).and_return(test_referral)
          end

          it 'logs with sanitized station_id as no_value' do
            allow_any_instance_of(VAOS::V2::AppointmentsService).to receive(:get_active_appointments_for_referral)
              .and_return({
                            EPS: { data: [] },
                            VAOS: { data: [] }
                          })

            expect(Rails.logger).to receive(:error)
              .with('Community Care Appointments: Referral detail view: Missing provider data', {
                      missing_data: [VAOS::V2::ReferralsController::REFERRING_FACILITY_CODE_FIELD],
                      station_id: 'no_value',
                      user_uuid: user.uuid
                    })
            get "/vaos/v2/referrals/#{encrypted_uuid}"
          end
        end

        context 'when both provider IDs are present' do
          it 'does not log any error' do
            allow_any_instance_of(VAOS::V2::AppointmentsService).to receive(:get_active_appointments_for_referral)
              .and_return({
                            EPS: { data: [] },
                            VAOS: { data: [] }
                          })

            allow(service_double).to receive(:get_referral)
              .with(referral_number, icn).and_return(referral)
            expect(Rails.logger).not_to receive(:error)
            get "/vaos/v2/referrals/#{encrypted_uuid}"
          end
        end
      end

      context 'when fetching the same referral multiple times' do
        let(:initial_time) { Time.current.to_f }
        let(:client) { Ccra::RedisClient.new }
        let(:referral) { build(:ccra_referral_detail, referral_number:) }

        before do
          allow(service_double).to receive(:get_referral)
            .with(referral_number, icn)
            .and_return(referral)

          # Set up initial booking start time in cache
          client.save_booking_start_time(
            referral_number:,
            booking_start_time: initial_time
          )
        end

        it 'preserves the original booking start time in the cache' do
          # First request
          get "/vaos/v2/referrals/#{encrypted_uuid}"
          cached_time = client.fetch_booking_start_time(referral_number:)
          expect(cached_time).to eq(initial_time)

          # Second request
          get "/vaos/v2/referrals/#{encrypted_uuid}"
          cached_time = client.fetch_booking_start_time(referral_number:)
          expect(cached_time).to eq(initial_time)
        end
      end

      context 'when fetching a referral for the first time' do
        let(:client) { Ccra::RedisClient.new }
        let(:referral) { build(:ccra_referral_detail, referral_number:) }

        before do
          Timecop.freeze
          allow(service_double).to receive(:get_referral) do |_id, _user_icn|
            # Simulate the service's behavior of setting the booking start time
            client.save_booking_start_time(
              referral_number:,
              booking_start_time: Time.current.to_f
            )
            referral
          end
        end

        after { Timecop.return }

        it 'sets the booking start time in the cache' do
          expect do
            get "/vaos/v2/referrals/#{encrypted_uuid}"
          end.to change {
            client.fetch_booking_start_time(referral_number:)
          }.from(nil).to(Time.current.to_f)
        end
      end
    end

    context 'when using invalid referral id' do
      let(:invalid_id) { 'invalid' }

      before do
        sign_in_as(user)
      end

      it 'returns appropriate error status' do
        get "/vaos/v2/referrals/#{invalid_id}"

        # Expecting bad request based on how the controller likely handles missing parameters
        expect(response).to have_http_status(:bad_request)
      end
    end
  end
end
