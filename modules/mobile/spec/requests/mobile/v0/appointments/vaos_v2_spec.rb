# frozen_string_literal: true

require_relative '../../../../support/helpers/rails_helper'
require_relative '../../../../support/helpers/committee_helper'

RSpec.describe 'Mobile::V0::Appointments::VAOSV2', type: :request do
  include JsonSchemaMatchers
  include CommitteeHelper

  let!(:user) { sis_user(icn: '1012846043V576341', vha_facility_ids: [402, 555]) }

  before do
    Flipper.enable_actor(:appointments_consolidation, user)
  end

  context 'with VAOS' do
    before do
      Flipper.disable(:va_online_scheduling_use_vpg)
    end

    describe 'GET /mobile/v0/appointments' do
      before do
        allow_any_instance_of(VAOS::UserService).to receive(:session).and_return('stubbed_token')
        allow(Rails.logger).to receive(:info)
        Timecop.freeze(Time.zone.parse('2022-01-01T19:25:00Z'))
      end

      after do
        Timecop.return
      end

      let(:start_date) { Time.zone.parse('2021-01-01T00:00:00Z').iso8601 }
      let(:end_date) { Time.zone.parse('2023-01-01T00:00:00Z').iso8601 }
      let(:params) { { startDate: start_date, endDate: end_date, include: ['pending'] } }

      describe 'authorization' do
        context 'when user does not have access' do
          let!(:user) { sis_user(:api_auth, :loa1, icn: nil) }

          it 'returns forbidden' do
            get('/mobile/v0/appointments', headers: sis_headers, params:)
            expect(response).to have_http_status(:forbidden)
            assert_schema_conform(403)
          end
        end

        context 'when user has access' do
          it 'returns ok' do
            VCR.use_cassette('mobile/appointments/VAOS_v2/get_clinics_200', match_requests_on: %i[method uri]) do
              VCR.use_cassette('mobile/appointments/VAOS_v2/get_facilities_200', match_requests_on: %i[method uri]) do
                VCR.use_cassette('mobile/appointments/VAOS_v2/get_appointment_200',
                                 match_requests_on: %i[method uri]) do
                  get '/mobile/v0/appointments', headers: sis_headers, params:
                end
              end
            end
            expect(response).to have_http_status(:ok)
            assert_schema_conform(200)
          end
        end
      end

      context 'backfill facility service returns data' do
        it 'location is populated' do
          VCR.use_cassette('mobile/appointments/VAOS_v2/get_clinics_200', match_requests_on: %i[method uri]) do
            VCR.use_cassette('mobile/appointments/VAOS_v2/get_facilities_200', match_requests_on: %i[method uri]) do
              VCR.use_cassette('mobile/appointments/VAOS_v2/get_appointment_200', match_requests_on: %i[method uri]) do
                get '/mobile/v0/appointments', headers: sis_headers, params:
              end
            end
          end
          expect(response).to have_http_status(:ok)
          location = response.parsed_body.dig('data', 0, 'attributes', 'location')
          physical_location = response.parsed_body.dig('data', 0, 'attributes', 'physicalLocation')
          comments = response.parsed_body.dig('data', 0, 'attributes', 'comment')
          reason = response.parsed_body.dig('data', 0, 'attributes', 'reason')
          expect(location).to eq({ 'id' => '983',
                                   'name' => 'Cheyenne VA Medical Center',
                                   'address' =>
                                     { 'street' => '2360 East Pershing Boulevard',
                                       'city' => 'Cheyenne',
                                       'state' => 'WY',
                                       'zipCode' => '82001-5356' },
                                   'lat' => 41.148026,
                                   'long' => -104.786255,
                                   'phone' =>
                                     { 'areaCode' => '307', 'number' => '778-7550',
                                       'extension' => nil },
                                   'url' => nil,
                                   'code' => nil })
          expect(physical_location).to eq('MTZ OPC, LAB')
          expect(comments).to eq('My leg!')
          expect(reason).to eq('Routine/Follow-up')
          expect(response.parsed_body['meta']).to eq({
                                                       'pagination' => { 'currentPage' => 1,
                                                                         'perPage' => 10,
                                                                         'totalPages' => 1,
                                                                         'totalEntries' => 1 },
                                                       'upcomingAppointmentsCount' => 0,
                                                       'upcomingDaysLimit' => 30
                                                     })
        end
      end

      context 'backfill facility service returns in error' do
        it 'location is nil' do
          VCR.use_cassette('mobile/appointments/VAOS_v2/get_clinics_200', match_requests_on: %i[method uri]) do
            VCR.use_cassette('mobile/appointments/VAOS_v2/get_facility_500', match_requests_on: %i[method uri],
                                                                             allow_playback_repeats: true) do
              VCR.use_cassette('mobile/appointments/VAOS_v2/get_appointment_200', match_requests_on: %i[method uri]) do
                get '/mobile/v0/appointments', headers: sis_headers, params:
              end
            end
          end
          expect(response).to have_http_status(:ok)
          assert_schema_conform(200)
          location = response.parsed_body.dig('data', 0, 'attributes', 'location')
          expect(location).to eq({ 'id' => nil,
                                   'name' => nil,
                                   'address' =>
                                     { 'street' => nil,
                                       'city' => nil,
                                       'state' => nil,
                                       'zipCode' => nil },
                                   'lat' => nil,
                                   'long' => nil,
                                   'phone' =>
                                     { 'areaCode' => nil,
                                       'number' => nil,
                                       'extension' => nil },
                                   'url' => nil,
                                   'code' => nil })
        end
      end

      context 'backfill clinic service returns data' do
        it 'vetextId is correct' do
          VCR.use_cassette('mobile/appointments/VAOS_v2/get_clinics_200', match_requests_on: %i[method uri]) do
            VCR.use_cassette('mobile/appointments/VAOS_v2/get_facilities_200', match_requests_on: %i[method uri]) do
              VCR.use_cassette('mobile/appointments/VAOS_v2/get_appointment_200', match_requests_on: %i[method uri]) do
                get '/mobile/v0/appointments', headers: sis_headers, params:
              end
            end
          end
          expect(response.parsed_body.dig('data', 0, 'attributes', 'vetextId')).to eq('442;3220827.043')
        end
      end

      context 'backfill clinic service uses facility id that does not exist' do
        it 'healthcareService is nil' do
          allow_any_instance_of(VAOS::V2::MobileFacilityService).to receive(:get_clinic!).and_return(nil)
          VCR.use_cassette('mobile/appointments/VAOS_v2/get_facility_404', match_requests_on: %i[method uri]) do
            VCR.use_cassette('mobile/appointments/VAOS_v2/get_clinic_bad_facility_id_500',
                             match_requests_on: %i[method uri]) do
              VCR.use_cassette('mobile/appointments/VAOS_v2/get_appointment_200_bad_facility_id',
                               match_requests_on: %i[method uri]) do
                get '/mobile/v0/appointments', headers: sis_headers, params:
              end
            end
          end
          expect(response).to have_http_status(:ok)
          assert_schema_conform(200)
          expect(response.parsed_body.dig('data', 0, 'attributes', 'healthcareService')).to be_nil
        end

        it 'attempts to fetch clinic once' do
          allow_any_instance_of(VAOS::V2::MobileFacilityService).to receive(:get_clinic!).and_return(nil)
          expect_any_instance_of(VAOS::V2::MobileFacilityService).to receive(:get_clinic!).once

          VCR.use_cassette('mobile/appointments/VAOS_v2/get_facilities_200', match_requests_on: %i[method uri]) do
            VCR.use_cassette('mobile/appointments/VAOS_v2/get_clinic_bad_facility_id_500',
                             match_requests_on: %i[method uri]) do
              VCR.use_cassette('mobile/appointments/VAOS_v2/get_appointments_bad_facility_200',
                               match_requests_on: %i[method uri]) do
                get '/mobile/v0/appointments', headers: sis_headers, params:
              end
            end
          end
        end
      end

      context 'when partial appointments data is received' do
        it 'has access and returned va appointments having partial errors' do
          VCR.use_cassette('mobile/appointments/VAOS_v2/get_clinics_200', match_requests_on: %i[method uri]) do
            VCR.use_cassette('mobile/appointments/VAOS_v2/get_facilities_200', match_requests_on: %i[method uri]) do
              VCR.use_cassette('mobile/appointments/VAOS_v2/get_appointment_200_partial_error',
                               match_requests_on: %i[method uri]) do
                get '/mobile/v0/appointments', headers: sis_headers, params:
              end
            end
          end

          expect(response).to have_http_status(:multi_status)
          assert_schema_conform(207)
          expect(response.parsed_body['data'].count).to eq(1)
          expect(response.parsed_body['meta']).to include(
            {
              'errors' => [{ 'source' => 'VA Service' }]
            }
          )
        end
      end

      context 'request telehealth onsite appointment' do
        let(:start_date) { Time.zone.parse('1991-01-01T00:00:00Z').iso8601 }
        let(:end_date) { Time.zone.parse('2023-01-01T00:00:00Z').iso8601 }
        let(:params) do
          { page: { number: 1, size: 9999 }, startDate: start_date, endDate: end_date }
        end

        it 'processes appointments without error' do
          VCR.use_cassette('mobile/appointments/VAOS_v2/get_clinics_200', match_requests_on: %i[method uri]) do
            VCR.use_cassette('mobile/appointments/VAOS_v2/get_facilities_200', match_requests_on: %i[method uri]) do
              VCR.use_cassette('mobile/appointments/VAOS_v2/get_appointment_200_telehealth_onsite',
                               match_requests_on: %i[method uri]) do
                VCR.use_cassette('mobile/providers/get_provider_200', match_requests_on: %i[method uri],
                                                                      tag: :force_utf8) do
                  get '/mobile/v0/appointments', headers: sis_headers, params:
                end
              end
            end
          end
          attributes = response.parsed_body.dig('data', 0, 'attributes')
          expect(response).to have_http_status(:ok)
          assert_schema_conform(200)

          expect(attributes['appointmentType']).to eq('VA_VIDEO_CONNECT_ONSITE')
          expect(attributes['location']).to eq({ 'id' => '983',
                                                 'name' => 'Cheyenne VA Medical Center',
                                                 'address' =>
                                                   { 'street' => '2360 East Pershing Boulevard',
                                                     'city' => 'Cheyenne',
                                                     'state' => 'WY',
                                                     'zipCode' => '82001-5356' },
                                                 'lat' => 41.148026,
                                                 'long' => -104.786255,
                                                 'phone' =>
                                                   { 'areaCode' => '307',
                                                     'number' => '778-7550',
                                                     'extension' => nil },
                                                 'url' => nil,
                                                 'code' => nil })
        end
      end

      describe 'healthcare provider names' do
        let(:erb_template_params) { { start_date: '2021-01-01T00:00:00Z', end_date: '2023-01-26T23:59:59Z' } }

        it 'is set as expected' do
          VCR.use_cassette('mobile/appointments/VAOS_v2/get_clinics_200', match_requests_on: %i[method uri]) do
            VCR.use_cassette('mobile/appointments/VAOS_v2/get_facilities_200', match_requests_on: %i[method uri]) do
              VCR.use_cassette('mobile/appointments/VAOS_v2/get_appointments_with_mixed_provider_types',
                               erb: erb_template_params,
                               match_requests_on: %i[method uri]) do
                VCR.use_cassette('mobile/providers/get_provider_200', match_requests_on: %i[method uri],
                                                                      tag: :force_utf8) do
                  get '/mobile/v0/appointments', headers: sis_headers
                end
              end
            end
          end

          expect(response).to have_http_status(:ok)
          assert_schema_conform(200)

          appointments = response.parsed_body['data']
          appointment_without_provider = appointments.find { |appt| appt['id'] == '76131' }
          proposed_cc_appointment_with_provider = appointments.find { |appt| appt['id'] == '76132' }
          appointment_with_practitioner_list = appointments.find { |appt| appt['id'] == '76133' }

          expect(appointment_without_provider['attributes']['healthcareProvider']).to be_nil
          expect(proposed_cc_appointment_with_provider['attributes']['healthcareProvider']).to eq('DEHGHAN, AMIR')
          expect(appointment_with_practitioner_list['attributes']['healthcareProvider']).to eq('MATTHEW ENGHAUSER')
        end
      end

      describe 'appointment IEN' do
        context 'when appointment identifier with the system VistADefinedTerms/409_84 is found' do
          it 'finds an appointment ien' do
            VCR.use_cassette('mobile/appointments/VAOS_v2/get_clinics_200', match_requests_on: %i[method uri]) do
              VCR.use_cassette('mobile/appointments/VAOS_v2/get_facilities_200', match_requests_on: %i[method uri]) do
                VCR.use_cassette('mobile/appointments/VAOS_v2/get_appointment_with_ien_200',
                                 match_requests_on: %i[method uri]) do
                  get '/mobile/v0/appointments', headers: sis_headers, params:
                end
              end
            end

            expect(response).to have_http_status(:ok)
            assert_schema_conform(200)

            appt_ien = response.parsed_body.dig('data', 0, 'attributes', 'appointmentIen')
            expect(appt_ien).to eq('11461')
          end
        end

        context 'when appointment identifier with the system VistADefinedTerms/409_84 is not found' do
          it 'sets appointment ien to nil' do
            VCR.use_cassette('mobile/appointments/VAOS_v2/get_clinics_200', match_requests_on: %i[method uri]) do
              VCR.use_cassette('mobile/appointments/VAOS_v2/get_facilities_200', match_requests_on: %i[method uri]) do
                VCR.use_cassette('mobile/appointments/VAOS_v2/get_appointment_200',
                                 match_requests_on: %i[method uri]) do
                  get '/mobile/v0/appointments', headers: sis_headers, params:
                end
              end
            end
            appt_ien = response.parsed_body.dig('data', 0, 'attributes', 'appointmentIen')
            expect(appt_ien).to be_nil
          end
        end
      end

      describe 'upcoming_appointments_count and upcoming_days_limit' do
        before { Timecop.freeze(Time.zone.parse('2022-01-24T00:00:00Z')) }

        it 'includes the upcoming_days_limit and a count of booked appointments within that limit in the meta' do
          VCR.use_cassette('mobile/appointments/VAOS_v2/get_clinics_200', match_requests_on: %i[method uri]) do
            VCR.use_cassette('mobile/appointments/VAOS_v2/get_facilities_200', match_requests_on: %i[method uri]) do
              VCR.use_cassette('mobile/appointments/VAOS_v2/get_appointments_with_mixed_provider_types',
                               erb: { start_date: '2021-01-01T00:00:00Z', end_date: '2023-02-18T23:59:59Z' },
                               match_requests_on: %i[method uri]) do
                VCR.use_cassette('mobile/providers/get_provider_200', match_requests_on: %i[method uri],
                                                                      tag: :force_utf8) do
                  get '/mobile/v0/appointments', headers: sis_headers
                end
              end
            end
          end

          expected_upcoming_pending_count = response.parsed_body['data'].count do |appt|
            appt_start_time = DateTime.parse(appt['attributes']['startDateUtc'])
            appt['attributes']['isPending'] == false && appt['attributes']['status'] == 'BOOKED' &&
              appt_start_time > Time.now.utc && appt_start_time <= 2.weeks.from_now.end_of_day.utc
          end
          expect(expected_upcoming_pending_count).to eq(1)
          expect(response.parsed_body['meta']['upcomingAppointmentsCount']).to eq(expected_upcoming_pending_count)
          expect(response.parsed_body['meta']['upcomingDaysLimit']).to eq(30)
        end
      end

      context 'when custom error response is injected' do
        let!(:user) { sis_user(email: 'vets.gov.user+141@gmail.com', vha_facility_ids: [402, 555]) }

        it 'raises 418 custom error' do
          with_settings(Settings, vsp_environment: 'test') do
            get '/mobile/v0/appointments', headers: sis_headers
          end
          expect(response).to have_http_status(418)
          assert_schema_conform(418)
          expect(response.parsed_body).to eq({ 'errors' => [{ 'title' => 'Custom error title',
                                                              'body' => 'Custom error body. \\n This explains to ' \
                                                                        'the user the details of the ongoing issue.',
                                                              'status' => 418,
                                                              'source' => 'VAOS',
                                                              'telephone' => '999-999-9999',
                                                              'refreshable' => true }] })
        end
      end
    end
  end

  context 'with VPG' do
    before do
      Flipper.enable(:va_online_scheduling_use_vpg)
    end

    describe 'GET /mobile/v0/appointments' do
      before do
        allow_any_instance_of(VAOS::UserService).to receive(:session).and_return('stubbed_token')
        allow(Rails.logger).to receive(:info)
        Timecop.freeze(Time.zone.parse('2022-01-01T19:25:00Z'))
      end

      after do
        Timecop.return
      end

      let(:start_date) { Time.zone.parse('2021-01-01T00:00:00Z').iso8601 }
      let(:end_date) { Time.zone.parse('2023-01-01T00:00:00Z').iso8601 }
      let(:params) { { startDate: start_date, endDate: end_date, include: ['pending'] } }

      describe 'authorization' do
        context 'when user does not have access' do
          let!(:user) { sis_user(:api_auth, :loa1, icn: nil) }

          it 'returns forbidden' do
            get('/mobile/v0/appointments', headers: sis_headers, params:)
            expect(response).to have_http_status(:forbidden)
            assert_schema_conform(403)
          end
        end

        context 'user has access' do
          it 'returns ok' do
            VCR.use_cassette('mobile/appointments/VAOS_v2/get_clinics_200', match_requests_on: %i[method uri]) do
              VCR.use_cassette('mobile/appointments/VAOS_v2/get_facilities_200', match_requests_on: %i[method uri]) do
                VCR.use_cassette('mobile/appointments/VAOS_v2/get_appointment_200_vpg',
                                 match_requests_on: %i[method uri]) do
                  get '/mobile/v0/appointments', headers: sis_headers, params:
                end
              end
            end
            expect(response).to have_http_status(:ok)
            assert_schema_conform(200)
          end
        end
      end

      context 'backfill facility service returns data' do
        it 'location is populated' do
          VCR.use_cassette('mobile/appointments/VAOS_v2/get_clinics_200', match_requests_on: %i[method uri]) do
            VCR.use_cassette('mobile/appointments/VAOS_v2/get_facilities_200', match_requests_on: %i[method uri]) do
              VCR.use_cassette('mobile/appointments/VAOS_v2/get_appointment_200_vpg',
                               match_requests_on: %i[method uri]) do
                get '/mobile/v0/appointments', headers: sis_headers, params:
              end
            end
          end
          expect(response).to have_http_status(:ok)
          location = response.parsed_body.dig('data', 0, 'attributes', 'location')
          physical_location = response.parsed_body.dig('data', 0, 'attributes', 'physicalLocation')
          expect(location).to eq({ 'id' => '983',
                                   'name' => 'Cheyenne VA Medical Center',
                                   'address' =>
                                     { 'street' => '2360 East Pershing Boulevard',
                                       'city' => 'Cheyenne',
                                       'state' => 'WY',
                                       'zipCode' => '82001-5356' },
                                   'lat' => 41.148026,
                                   'long' => -104.786255,
                                   'phone' =>
                                     { 'areaCode' => '307', 'number' => '778-7550',
                                       'extension' => nil },
                                   'url' => nil,
                                   'code' => nil })
          expect(physical_location).to eq('MTZ OPC, LAB')
          expect(response.parsed_body['meta']).to eq({
                                                       'pagination' => { 'currentPage' => 1,
                                                                         'perPage' => 10,
                                                                         'totalPages' => 1,
                                                                         'totalEntries' => 1 },
                                                       'upcomingAppointmentsCount' => 0,
                                                       'upcomingDaysLimit' => 30
                                                     })
        end
      end

      context 'backfill facility service returns in error' do
        it 'location is nil' do
          VCR.use_cassette('mobile/appointments/VAOS_v2/get_clinics_200', match_requests_on: %i[method uri]) do
            VCR.use_cassette('mobile/appointments/VAOS_v2/get_facility_500', match_requests_on: %i[method uri],
                                                                             allow_playback_repeats: true) do
              VCR.use_cassette('mobile/appointments/VAOS_v2/get_appointment_200_vpg',
                               match_requests_on: %i[method uri]) do
                get '/mobile/v0/appointments', headers: sis_headers, params:
              end
            end
          end
          expect(response).to have_http_status(:ok)
          assert_schema_conform(200)
          location = response.parsed_body.dig('data', 0, 'attributes', 'location')
          expect(location).to eq({ 'id' => nil,
                                   'name' => nil,
                                   'address' =>
                                     { 'street' => nil,
                                       'city' => nil,
                                       'state' => nil,
                                       'zipCode' => nil },
                                   'lat' => nil,
                                   'long' => nil,
                                   'phone' =>
                                     { 'areaCode' => nil,
                                       'number' => nil,
                                       'extension' => nil },
                                   'url' => nil,
                                   'code' => nil })
        end
      end

      context 'backfill clinic service returns data' do
        it 'vetextId is correct' do
          VCR.use_cassette('mobile/appointments/VAOS_v2/get_clinics_200', match_requests_on: %i[method uri]) do
            VCR.use_cassette('mobile/appointments/VAOS_v2/get_facilities_200', match_requests_on: %i[method uri]) do
              VCR.use_cassette('mobile/appointments/VAOS_v2/get_appointment_200_vpg',
                               match_requests_on: %i[method uri]) do
                get '/mobile/v0/appointments', headers: sis_headers, params:
              end
            end
          end
          expect(response.parsed_body.dig('data', 0, 'attributes', 'vetextId')).to eq('442;3220827.043')
        end
      end

      context 'backfill clinic service uses facility id that does not exist' do
        it 'healthcareService is nil' do
          allow_any_instance_of(VAOS::V2::MobileFacilityService).to receive(:get_clinic!).and_return(nil)
          VCR.use_cassette('mobile/appointments/VAOS_v2/get_facility_404', match_requests_on: %i[method uri]) do
            VCR.use_cassette('mobile/appointments/VAOS_v2/get_clinic_bad_facility_id_500',
                             match_requests_on: %i[method uri]) do
              VCR.use_cassette('mobile/appointments/VAOS_v2/get_appointment_200_bad_facility_id_vpg',
                               match_requests_on: %i[method uri]) do
                get '/mobile/v0/appointments', headers: sis_headers, params:
              end
            end
          end
          expect(response).to have_http_status(:ok)
          assert_schema_conform(200)
          expect(response.parsed_body.dig('data', 0, 'attributes', 'healthcareService')).to be_nil
        end

        it 'attempts to fetch clinic once' do
          allow_any_instance_of(VAOS::V2::MobileFacilityService).to receive(:get_clinic!).and_return(nil)
          expect_any_instance_of(VAOS::V2::MobileFacilityService).to receive(:get_clinic!).once

          VCR.use_cassette('mobile/appointments/VAOS_v2/get_facilities_200', match_requests_on: %i[method uri]) do
            VCR.use_cassette('mobile/appointments/VAOS_v2/get_clinic_bad_facility_id_500',
                             match_requests_on: %i[method uri]) do
              VCR.use_cassette('mobile/appointments/VAOS_v2/get_appointments_bad_facility_200_vpg',
                               match_requests_on: %i[method uri]) do
                get '/mobile/v0/appointments', headers: sis_headers, params:
              end
            end
          end
        end
      end

      context 'when partial appointments data is received' do
        it 'has access and returned va appointments having partial errors' do
          VCR.use_cassette('mobile/appointments/VAOS_v2/get_clinics_200', match_requests_on: %i[method uri]) do
            VCR.use_cassette('mobile/appointments/VAOS_v2/get_facilities_200', match_requests_on: %i[method uri]) do
              VCR.use_cassette('mobile/appointments/VAOS_v2/get_appointment_200_partial_error_vpg',
                               match_requests_on: %i[method uri]) do
                get '/mobile/v0/appointments', headers: sis_headers, params:
              end
            end
          end

          expect(response).to have_http_status(:multi_status)
          assert_schema_conform(207)
          expect(response.parsed_body['data'].count).to eq(1)
          expect(response.parsed_body['meta']).to include(
            {
              'errors' => [{ 'source' => 'VA Service' }]
            }
          )
        end
      end

      context 'request telehealth onsite appointment' do
        let(:start_date) { Time.zone.parse('1991-01-01T00:00:00Z').iso8601 }
        let(:end_date) { Time.zone.parse('2023-01-01T00:00:00Z').iso8601 }
        let(:params) do
          { page: { number: 1, size: 9999 }, startDate: start_date, endDate: end_date }
        end

        it 'processes appointments without error' do
          VCR.use_cassette('mobile/appointments/VAOS_v2/get_clinics_200', match_requests_on: %i[method uri]) do
            VCR.use_cassette('mobile/appointments/VAOS_v2/get_facilities_200', match_requests_on: %i[method uri]) do
              VCR.use_cassette('mobile/appointments/VAOS_v2/get_appointment_200_telehealth_onsite_vpg',
                               match_requests_on: %i[method uri]) do
                VCR.use_cassette('mobile/providers/get_provider_200', match_requests_on: %i[method uri],
                                                                      tag: :force_utf8) do
                  get '/mobile/v0/appointments', headers: sis_headers, params:
                end
              end
            end
          end
          attributes = response.parsed_body.dig('data', 0, 'attributes')
          expect(response).to have_http_status(:ok)
          assert_schema_conform(200)

          expect(attributes['appointmentType']).to eq('VA_VIDEO_CONNECT_ONSITE')
          expect(attributes['location']).to eq({ 'id' => '983',
                                                 'name' => 'Cheyenne VA Medical Center',
                                                 'address' =>
                                                   { 'street' => '2360 East Pershing Boulevard',
                                                     'city' => 'Cheyenne',
                                                     'state' => 'WY',
                                                     'zipCode' => '82001-5356' },
                                                 'lat' => 41.148026,
                                                 'long' => -104.786255,
                                                 'phone' =>
                                                   { 'areaCode' => '307',
                                                     'number' => '778-7550',
                                                     'extension' => nil },
                                                 'url' => nil,
                                                 'code' => nil })
        end
      end

      describe 'healthcare provider names' do
        let(:erb_template_params) { { start_date: '2021-01-01T00:00:00Z', end_date: '2023-01-26T23:59:59Z' } }

        it 'is set as expected' do
          VCR.use_cassette('mobile/appointments/VAOS_v2/get_clinics_200', match_requests_on: %i[method uri]) do
            VCR.use_cassette('mobile/appointments/VAOS_v2/get_facilities_200', match_requests_on: %i[method uri]) do
              VCR.use_cassette('mobile/appointments/VAOS_v2/get_appointments_with_mixed_provider_types_vpg',
                               erb: erb_template_params,
                               match_requests_on: %i[method uri]) do
                VCR.use_cassette('mobile/providers/get_provider_200', match_requests_on: %i[method uri],
                                                                      tag: :force_utf8) do
                  get '/mobile/v0/appointments', headers: sis_headers
                end
              end
            end
          end

          expect(response).to have_http_status(:ok)
          assert_schema_conform(200)

          appointments = response.parsed_body['data']

          appointment_without_provider = appointments.find { |appt| appt['id'] == '76131' }
          proposed_cc_appointment_with_provider = appointments.find { |appt| appt['id'] == '76132' }
          appointment_with_practitioner_list = appointments.find { |appt| appt['id'] == '76133' }

          expect(appointment_without_provider['attributes']['healthcareProvider']).to be_nil
          expect(proposed_cc_appointment_with_provider['attributes']['healthcareProvider']).to eq('DEHGHAN, AMIR')
          expect(appointment_with_practitioner_list['attributes']['healthcareProvider']).to eq('MATTHEW ENGHAUSER')
        end
      end

      describe 'appointment IEN' do
        context 'when appointment identifier with the system VistADefinedTerms/409_84 is found' do
          it 'finds an appointment ien' do
            VCR.use_cassette('mobile/appointments/VAOS_v2/get_clinics_200', match_requests_on: %i[method uri]) do
              VCR.use_cassette('mobile/appointments/VAOS_v2/get_facilities_200', match_requests_on: %i[method uri]) do
                VCR.use_cassette('mobile/appointments/VAOS_v2/get_appointment_with_ien_200_vpg',
                                 match_requests_on: %i[method uri]) do
                  get '/mobile/v0/appointments', headers: sis_headers, params:
                end
              end
            end
            appt_ien = response.parsed_body.dig('data', 0, 'attributes', 'appointmentIen')
            assert_schema_conform(200)
            expect(appt_ien).to eq('11461')
          end
        end

        context 'when appointment identifier with the system VistADefinedTerms/409_84 is not found' do
          it 'sets appointment ien to nil' do
            VCR.use_cassette('mobile/appointments/VAOS_v2/get_clinics_200', match_requests_on: %i[method uri]) do
              VCR.use_cassette('mobile/appointments/VAOS_v2/get_facilities_200', match_requests_on: %i[method uri]) do
                VCR.use_cassette('mobile/appointments/VAOS_v2/get_appointment_200_vpg',
                                 match_requests_on: %i[method uri]) do
                  get '/mobile/v0/appointments', headers: sis_headers, params:
                end
              end
            end
            appt_ien = response.parsed_body.dig('data', 0, 'attributes', 'appointmentIen')
            expect(appt_ien).to be_nil
          end
        end
      end

      describe 'upcoming_appointments_count and upcoming_days_limit' do
        before { Timecop.freeze(Time.zone.parse('2022-01-24T00:00:00Z')) }

        it 'includes the upcoming_days_limit and a count of booked appointments within that limit in the meta' do
          VCR.use_cassette('mobile/appointments/VAOS_v2/get_clinics_200', match_requests_on: %i[method uri]) do
            VCR.use_cassette('mobile/appointments/VAOS_v2/get_facilities_200', match_requests_on: %i[method uri]) do
              VCR.use_cassette('mobile/appointments/VAOS_v2/get_appointments_with_mixed_provider_types_vpg',
                               erb: { start_date: '2021-01-01T00:00:00Z', end_date: '2023-02-18T23:59:59Z' },
                               match_requests_on: %i[method uri]) do
                VCR.use_cassette('mobile/providers/get_provider_200', match_requests_on: %i[method uri],
                                                                      tag: :force_utf8) do
                  get '/mobile/v0/appointments', headers: sis_headers
                end
              end
            end
          end

          expected_upcoming_pending_count = response.parsed_body['data'].count do |appt|
            appt_start_time = DateTime.parse(appt['attributes']['startDateUtc'])
            appt['attributes']['isPending'] == false && appt['attributes']['status'] == 'BOOKED' &&
              appt_start_time > Time.now.utc && appt_start_time <= 2.weeks.from_now.end_of_day.utc
          end
          expect(expected_upcoming_pending_count).to eq(1)
          expect(response.parsed_body['meta']['upcomingAppointmentsCount']).to eq(expected_upcoming_pending_count)
          expect(response.parsed_body['meta']['upcomingDaysLimit']).to eq(30)
        end
      end

      describe 'appointment call returns 500 error' do
        # This is a requirement due to FE having a bug where a source field in the error
        # with a hash in it was causing long delays.
        it 'returns 502 error with no source hash' do
          VCR.use_cassette('mobile/appointments/VAOS_v2/get_appointment_500', match_requests_on: %i[method uri]) do
            get '/mobile/v0/appointments', headers: sis_headers
          end
          assert_schema_conform(502)
          expect(response.parsed_body.dig('errors', 0)).to eq({ 'title' => 'Bad Gateway',
                                                                'detail' => 'The resource could not be found',
                                                                'code' => '502',
                                                                'status' => '502' })
        end
      end

      context 'appointment authorization' do
        context 'when user has no facilities' do
          let!(:user) { sis_user(icn: '1012846043V576341', vha_facility_ids: []) }

          it 'returns forbidden error' do
            VCR.use_cassette('mobile/appointments/VAOS_v2/get_appointment_200', match_requests_on: %i[method uri]) do
              get '/mobile/v0/appointments', headers: sis_headers
            end

            expect(response.parsed_body.dig('errors', 0)).to eq({ 'title' => 'Forbidden',
                                                                  'detail' => 'No facility associated with user',
                                                                  'code' => '403',
                                                                  'status' => '403' })
          end
        end
      end
    end
  end
end
