# frozen_string_literal: true

require 'rails_helper'
require 'unified_health_data/service'
require 'unique_user_events'

RSpec.describe 'VAOS::V2::Appointments', :skip_mvi, type: :request do
  include SchemaMatchers
  before do
    allow(Settings.mhv).to receive(:facility_range).and_return([[1, 999]])
    allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_vaos_alternate_route).and_return(false)
    allow(Flipper).to receive(:enabled?).with(:appointments_consolidation, instance_of(User)).and_return(true)
    # Configure EPS settings
    allow(Settings.vaos.eps).to receive_messages(
      access_token_url: 'https://login.wellhive.com/oauth2/default/v1/token',
      api_url: 'https://api.wellhive.com',
      base_path: 'care-navigation/v1'
    )
    allow(Settings.vaos.ccra).to receive_messages(
      api_url: 'http://test.example.com',
      base_path: 'vaos/v1/patients'
    )
    sign_in_as(current_user)
    allow_any_instance_of(VAOS::UserService).to receive(:session).and_return('stubbed_token')
  end

  let(:described_class) { VAOS::V2::AppointmentsController }

  let(:mock_clinic) do
    {
      service_name: 'service_name',
      physical_location: 'physical_location'
    }
  end

  let(:mock_clinic_without_physical_location) { { service_name: 'service_name' } }

  let(:mock_facility) do
    {
      test: 'test',
      id: '668',
      name: 'COL OR 1',
      timezone: {
        time_zone_id: 'America/New_York'
      }
    }
  end

  let(:expected_facility) do
    {
      'test' => 'test',
      'id' => '668',
      'name' => 'COL OR 1',
      'timezone' => {
        'timeZoneId' => 'America/New_York'
      }
    }
  end

  let(:mock_appt_location_openstruct) do
    OpenStruct.new({
                     id: '983',
                     vistaSite: '983',
                     vastParent: '983',
                     type: 'va_facilities',
                     name: 'COL OR 1',
                     classification: 'VA Medical Center (VAMC)',
                     lat: 39.744507,
                     long: -104.830956,
                     website: 'https://www.denver.va.gov/locations/directions.asp',
                     phone: {
                       main: '307-778-7550',
                       fax: '307-778-7381',
                       pharmacy: '866-420-6337',
                       afterHours: '307-778-7550',
                       patientAdvocate: '307-778-7550 x7517',
                       mentalHealthClinic: '307-778-7349',
                       enrollmentCoordinator: '307-778-7550 x7579'
                     },
                     physicalAddress: {
                       type: 'physical',
                       line: ['2360 East Pershing Boulevard'],
                       city: 'Cheyenne',
                       state: 'WY',
                       postalCode: '82001-5356'
                     },
                     mobile: false,
                     healthService: %w[Audiology Cardiology DentalServices EmergencyCare Gastroenterology
                                       Gynecology MentalHealthCare Nutrition Ophthalmology Optometry Orthopedics
                                       Podiatry PrimaryCare SpecialtyCare UrgentCare Urology WomensHealth],
                     operatingStatus: {
                       code: 'NORMAL'
                     }
                   })
  end

  let(:inflection_header) { { 'X-Key-Inflection' => 'camel' } }

  let(:provider_response) do
    OpenStruct.new({ 'providerIdentifier' => '1407938061', 'name' => 'DEHGHAN, AMIR' })
  end

  let(:provider_response2) do
    OpenStruct.new({ 'providerIdentifier' => '1528231610', 'name' => 'CARLTON, ROBERT A  ' })
  end

  let(:provider_response3) do
    OpenStruct.new({ 'providerIdentifier' => '1174506877', 'name' => 'BRIANT G MOYLES' })
  end

  def stub_facilities
    allow_any_instance_of(VAOS::V2::MobileFacilityService).to receive(:get_facility).and_return(mock_facility)
  end

  def stub_clinics
    allow_any_instance_of(VAOS::V2::MobileFacilityService).to receive(:get_clinic).and_return(mock_clinic)
  end

  context 'with jacqueline morgan' do
    let(:current_user) { build(:user, :jac) }

    context 'with VAOS' do
      before do
        allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_use_vpg, instance_of(User)).and_return(false)
        allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_use_vpg).and_return(false)
      end

      describe 'CREATE cc appointment' do
        let(:community_cares_request_body) do
          build(:appointment_form_v2, :community_cares, user: current_user).attributes
        end

        let(:community_cares_request_body2) do
          build(:appointment_form_v2, :community_cares2, user: current_user).attributes
        end

        it 'creates the cc appointment' do
          VCR.use_cassette('vaos/v2/appointments/post_appointments_cc_200_with_provider',
                           match_requests_on: %i[method path query]) do
            VCR.use_cassette('vaos/v2/mobile_facility_service/get_facility_200',
                             match_requests_on: %i[method path query]) do
              allow_any_instance_of(VAOS::V2::MobilePPMSService).to \
                receive(:get_provider_with_cache).with('1174506877').and_return(provider_response3)
              post '/vaos/v2/appointments', params: community_cares_request_body2, headers: inflection_header

              expect(response).to have_http_status(:created)
              json_body = json_body_for(response)
              expect(json_body.dig('attributes', 'preferredProviderName')).to eq('BRIANT G MOYLES')
              expect(json_body.dig('attributes', 'requestedPeriods', 0, 'localStartTime'))
                .to eq('2023-01-17T00:00:00.000-07:00')
              expect(json_body).to match_camelized_schema('vaos/v2/appointment', { strict: false })
            end
          end
        end

        it 'returns a 400 error' do
          VCR.use_cassette('vaos/v2/appointments/post_appointments_400', match_requests_on: %i[method path query]) do
            post '/vaos/v2/appointments', params: community_cares_request_body
            expect(response).to have_http_status(:bad_request)
            expect(JSON.parse(response.body)['errors'][0]['status']).to eq('400')
            expect(JSON.parse(response.body)['errors'][0]['detail']).to eq(
              'the patientIcn must match the ICN in the request URI'
            )
          end
        end
      end

      describe 'CREATE va appointment' do
        let(:va_booked_request_body) do
          build(:appointment_form_v2, :va_booked, user: current_user).attributes
        end

        let(:va_proposed_request_body) do
          build(:appointment_form_v2, :va_proposed_clinic, user: current_user).attributes
        end

        it 'creates the va appointment - proposed' do
          stub_facilities
          VCR.use_cassette('vaos/v2/appointments/post_appointments_va_proposed_clinic_200',
                           match_requests_on: %i[method path query]) do
            post '/vaos/v2/appointments', params: va_proposed_request_body, headers: inflection_header
            expect(response).to have_http_status(:created)
            expect(json_body_for(response)).to match_camelized_schema('vaos/v2/appointment', { strict: false })
          end
        end

        it 'creates the va appointment - booked' do
          stub_clinics
          VCR.use_cassette('vaos/v2/appointments/post_appointments_va_booked_200_JACQUELINE_M',
                           match_requests_on: %i[method path query]) do
            VCR.use_cassette('vaos/v2/mobile_facility_service/get_facility_200',
                             match_requests_on: %i[method path query]) do
              post '/vaos/v2/appointments', params: va_booked_request_body, headers: inflection_header
              expect(response).to have_http_status(:created)
              json_body = json_body_for(response)
              expect(json_body).to match_camelized_schema('vaos/v2/appointment', { strict: false })
              expect(json_body['attributes']['localStartTime']).to eq('2022-11-30T13:45:00.000-07:00')
            end
          end
        end

        it 'creates the va appointment and logs appointment details when there is a PAP COMPLIANCE comment' do
          stub_clinics
          VCR.use_cassette('vaos/v2/appointments/post_appointments_va_booked_200_and_log_facility',
                           match_requests_on: %i[method path query]) do
            VCR.use_cassette('vaos/v2/mobile_facility_service/get_facility_200',
                             match_requests_on: %i[method path query]) do
              allow(Rails.logger).to receive(:info).at_least(:once)
              post '/vaos/v2/appointments', params: va_booked_request_body, headers: inflection_header
              expect(response).to have_http_status(:created)
              json_body = json_body_for(response)
              expect(json_body).to match_camelized_schema('vaos/v2/appointment', { strict: false })
              expect(Rails.logger).to have_received(:info).with('Details for PAP COMPLIANCE/TELE appointment',
                                                                match("POST '/vaos/v1/patients/<icn>/appointments'"))
                                                          .at_least(:once)
              expect(json_body['attributes']['localStartTime']).to eq('2022-11-30T13:45:00.000-07:00')
            end
          end
        end
      end
    end

    context 'using VPG' do
      before do
        allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_use_vpg, instance_of(User)).and_return(true)
        allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_use_vpg).and_return(true)
      end

      describe 'CREATE cc appointment' do
        let(:community_cares_request_body) do
          build(:appointment_form_v2, :community_cares, user: current_user).attributes
        end

        let(:community_cares_request_body2) do
          build(:appointment_form_v2, :community_cares2, user: current_user).attributes
        end

        it 'creates the cc appointment' do
          VCR.use_cassette('vaos/v2/appointments/post_appointments_cc_200_with_provider_vpg',
                           match_requests_on: %i[method path query]) do
            VCR.use_cassette('vaos/v2/mobile_facility_service/get_facility_200',
                             match_requests_on: %i[method path query]) do
              allow_any_instance_of(VAOS::V2::MobilePPMSService).to \
                receive(:get_provider_with_cache).with('1174506877').and_return(provider_response3)
              post '/vaos/v2/appointments', params: community_cares_request_body2, headers: inflection_header

              expect(response).to have_http_status(:created)
              json_body = json_body_for(response)
              expect(json_body.dig('attributes', 'preferredProviderName')).to eq('BRIANT G MOYLES')
              expect(json_body.dig('attributes', 'requestedPeriods', 0, 'localStartTime'))
                .to eq('2023-01-17T00:00:00.000-07:00')
              expect(json_body).to match_camelized_schema('vaos/v2/appointment', { strict: false })
            end
          end
        end

        it 'returns a 400 error' do
          VCR.use_cassette('vaos/v2/appointments/post_appointments_400_vpg',
                           match_requests_on: %i[method path query]) do
            post '/vaos/v2/appointments', params: community_cares_request_body
            expect(response).to have_http_status(:bad_request)
            expect(JSON.parse(response.body)['errors'][0]['status']).to eq('400')
            expect(JSON.parse(response.body)['errors'][0]['detail']).to eq(
              'the patientIcn must match the ICN in the request URI'
            )
          end
        end
      end

      describe 'CREATE va appointment' do
        let(:va_booked_request_body) do
          build(:appointment_form_v2, :va_booked, user: current_user).attributes
        end

        let(:va_proposed_request_body) do
          build(:appointment_form_v2, :va_proposed_clinic, user: current_user).attributes
        end

        it 'creates the va appointment - proposed' do
          stub_facilities
          VCR.use_cassette('vaos/v2/appointments/post_appointments_va_proposed_clinic_200_vpg',
                           match_requests_on: %i[method path query]) do
            post '/vaos/v2/appointments', params: va_proposed_request_body, headers: inflection_header
            expect(response).to have_http_status(:created)
            expect(json_body_for(response)).to match_camelized_schema('vaos/v2/appointment', { strict: false })
          end
        end

        it 'creates the booked va appointment using VPG' do
          stub_clinics
          VCR.use_cassette('vaos/v2/appointments/post_appointments_va_booked_200_JACQUELINE_M_vpg',
                           match_requests_on: %i[method path query]) do
            VCR.use_cassette('vaos/v2/mobile_facility_service/get_facility_200',
                             match_requests_on: %i[method path query]) do
              post '/vaos/v2/appointments', params: va_booked_request_body, headers: inflection_header
              expect(response).to have_http_status(:created)
              json_body = json_body_for(response)
              expect(json_body).to match_camelized_schema('vaos/v2/appointment', { strict: false })
              expect(json_body['attributes']['localStartTime']).to eq('2022-11-30T13:45:00.000-07:00')
            end
          end
        end

        it 'creates the booked va appointment using VAOS' do
          allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_use_vpg,
                                                    instance_of(User)).and_return(false)

          stub_clinics
          VCR.use_cassette('vaos/v2/appointments/post_appointments_va_booked_200_JACQUELINE_M',
                           match_requests_on: %i[method path query]) do
            VCR.use_cassette('vaos/v2/mobile_facility_service/get_facility_200',
                             match_requests_on: %i[method path query]) do
              post '/vaos/v2/appointments', params: va_booked_request_body, headers: inflection_header
              expect(response).to have_http_status(:created)
              json_body = json_body_for(response)
              expect(json_body).to match_camelized_schema('vaos/v2/appointment', { strict: false })
              expect(json_body['attributes']['localStartTime']).to eq('2022-11-30T13:45:00.000-07:00')
            end
          end
        end

        it 'creates the va appointment and logs appointment details when there is a PAP COMPLIANCE comment' do
          stub_clinics
          VCR.use_cassette('vaos/v2/appointments/post_appointments_va_booked_200_and_log_facility_vpg',
                           match_requests_on: %i[method path query]) do
            VCR.use_cassette('vaos/v2/mobile_facility_service/get_facility_200',
                             match_requests_on: %i[method path query]) do
              allow(Rails.logger).to receive(:info).at_least(:once)
              post '/vaos/v2/appointments', params: va_booked_request_body, headers: inflection_header
              expect(response).to have_http_status(:created)
              json_body = json_body_for(response)
              expect(json_body).to match_camelized_schema('vaos/v2/appointment', { strict: false })
              expect(Rails.logger).to have_received(:info).with('Details for PAP COMPLIANCE/TELE appointment',
                                                                match("POST '/vpg/v1/patients/<icn>/appointments'"))
                                                          .at_least(:once)
              expect(json_body['attributes']['localStartTime']).to eq('2022-11-30T13:45:00.000-07:00')
            end
          end
        end
      end
    end

    describe 'GET appointments' do
      let(:start_date) { Time.zone.parse('2022-01-01T19:25:00Z') }
      let(:end_date) { Time.zone.parse('2022-12-01T19:45:00Z') }
      let(:params) { { start: start_date, end: end_date } }
      let(:facility_error_msg) { 'Error fetching facility details' }

      context 'as Judy Morrison' do
        let(:current_user) { build(:user, :vaos) }
        let(:start_date) { Time.zone.parse('2023-10-13T14:25:00Z') }
        let(:end_date) { Time.zone.parse('2023-10-13T17:45:00Z') }
        let(:params) { { start: start_date, end: end_date } }
        let(:avs_error) { 'Error retrieving AVS info' }
        let(:avs_path) do
          '/my-health/medical-records/summaries-and-notes/visit-summary/C46E12AA7582F5714716988663350853'
        end
        let(:avs_pdf) do
          [
            {
              'apptId' => '12345',
              'id' => '15249638961',
              'name' => 'Ambulatory Visit Summary',
              'loincCodes' => %w[4189669 96345-4],
              'noteType' => 'ambulatory_patient_summary',
              'contentType' => 'application/pdf'
            }
          ]
        end

        context 'using VAOS' do
          before do
            allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_use_vpg,
                                                      instance_of(User)).and_return(false)
            allow(Flipper).to receive(:enabled?).with('schema_contract_appointments_index').and_return(false)
            allow(Flipper).to receive(:enabled?).with(:travel_pay_view_claim_details,
                                                      instance_of(User)).and_return(false)
            allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_use_vpg).and_return(false)
          end

          it 'fetches appointment list and includes avs on past booked appointments' do
            VCR.use_cassette('vaos/v2/appointments/get_appointments_booked_past_avs_200',
                             match_requests_on: %i[method path query], allow_playback_repeats: true) do
              allow_any_instance_of(VAOS::V2::AppointmentsService).to receive(:get_avs_link)
                .and_return(avs_path)
              get '/vaos/v2/appointments' \
                  '?start=2023-10-13T14:25:00Z&end=2023-10-13T17:45:00Z&statuses=booked&_include=avs',
                  params:, headers: inflection_header

              data = JSON.parse(response.body)['data']

              expect(response).to have_http_status(:ok)
              expect(response.body).to be_a(String)

              expect(data[0]['attributes']['avsPath']).to eq(avs_path)

              expect(response).to match_camelized_response_schema('vaos/v2/appointments', { strict: false })
            end
          end

          it 'fetches appointment list and includes OH avs on past booked appointments' do
            VCR.use_cassette('vaos/v2/appointments/get_appointments_200_booked_cerner_avs',
                             match_requests_on: %i[method path query], allow_playback_repeats: true) do
              allow_any_instance_of(UnifiedHealthData::Service).to receive(:get_appt_avs).and_return(avs_pdf)
              get '/vaos/v2/appointments' \
                  '?start=2023-10-13T14:25:00Z&end=2023-10-13T17:45:00Z&statuses=booked&_include=avs',
                  params:, headers: inflection_header

              data = JSON.parse(response.body)['data']

              expect(response).to have_http_status(:ok)
              expect(response.body).to be_a(String)

              expect(data[0]['attributes']['avsPdf']).to eq(avs_pdf)

              expect(response).to match_camelized_response_schema('vaos/v2/appointments', { strict: false })
            end
          end

          it 'fetches appointment list that include eps appointments' do
            VCR.use_cassette('vaos/v2/appointments/get_appointments_booked_past_avs_200',
                             match_requests_on: %i[method path query], allow_playback_repeats: true) do
              VCR.use_cassette('vaos/eps/get_appointments/200',
                               match_requests_on: %i[method path query], allow_playback_repeats: true) do
                VCR.use_cassette('vaos/eps/search_provider_services/200',
                                 match_requests_on: %i[method path], allow_playback_repeats: true) do
                  VCR.use_cassette 'vaos/eps/token/token_200', match_requests_on: %i[method path] do
                    allow_any_instance_of(VAOS::V2::AppointmentsService).to receive(:get_avs_link)
                      .and_return(avs_path)

                    get '/vaos/v2/appointments' \
                        '?start=2023-10-13T14:25:00Z&end=2023-10-13T17:45:00Z&statuses=booked&_include=eps',
                        params:, headers: inflection_header

                    data = JSON.parse(response.body)['data']

                    expect(response).to have_http_status(:ok)
                    expect(response.body).to be_a(String)

                    expect(data.size).to eq(2)
                    data.each do |appointment|
                      expect(appointment['type']).to eq('appointments')
                      expect(appointment['attributes']['status']).to eq('booked')
                      expect { DateTime.iso8601(appointment['attributes']['start']) }.not_to raise_error
                    end
                    eps_appointment = data[1]
                    expect(eps_appointment['attributes']['modality']).to eq('communityCareEps')
                    expect(eps_appointment['attributes']['location']).to be_present
                    expect(eps_appointment['attributes']['location']['id']).to be_present
                    expect(eps_appointment['attributes']['location']['type']).to eq('appointments')
                    expect(eps_appointment['attributes']['location']['attributes']).to be_present
                    expect(eps_appointment['attributes']['location']['attributes']['name']).to eq(
                      'FHA Kissimmee Medical Campus'
                    )
                    expect(eps_appointment['attributes']['location']['attributes']['timezone']).to be_present
                    expect(eps_appointment['attributes']['location']['attributes']['timezone']['timeZoneId']).to eq(
                      'America/New_York'
                    )
                    expect(response).to match_camelized_response_schema('vaos/v2/appointments', { strict: false })
                  end
                end
              end
            end
          end

          it 'fetches appointment list and bypasses avs when query param is not included' do
            VCR.use_cassette('vaos/v2/appointments/get_appointments_booked_past_avs_200',
                             match_requests_on: %i[method path query], allow_playback_repeats: true) do
              allow_any_instance_of(VAOS::V2::AppointmentsService).to receive(:get_avs_link)
                .and_return(avs_path)
              get '/vaos/v2/appointments?start=2023-10-13T14:25:00Z&end=2023-10-13T17:45:00Z&statuses=booked',
                  params:, headers: inflection_header

              data = JSON.parse(response.body)['data']

              expect(response).to have_http_status(:ok)
              expect(response.body).to be_a(String)

              expect(data[0]['attributes']['avsPath']).to be_nil

              expect(response).to match_camelized_response_schema('vaos/v2/appointments', { strict: false })
            end
          end
        end
      end

      context 'requests a list of appointments' do
        context 'using VAOS' do
          before do
            Timecop.freeze(DateTime.parse('2021-09-02T14:00:00Z'))
            allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_use_vpg,
                                                      instance_of(User)).and_return(false)
            allow(Flipper).to receive(:enabled?).with('schema_contract_appointments_index').and_return(false)
            allow(Flipper).to receive(:enabled?).with(:travel_pay_view_claim_details,
                                                      instance_of(User)).and_return(false)
            allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_use_vpg).and_return(false)
          end

          after do
            Timecop.unfreeze
          end

          it 'has access and returns va appointments and honors includes' do
            allow(UniqueUserEvents).to receive(:log_event)

            stub_facilities
            stub_clinics
            VCR.use_cassette('vaos/v2/appointments/get_appointments_200_with_facilities_200',
                             match_requests_on: %i[method path query], allow_playback_repeats: true) do
              get '/vaos/v2/appointments?_include=facilities,clinics', params:, headers: inflection_header
              data = JSON.parse(response.body)['data']
              expect(response).to have_http_status(:ok)
              expect(response.body).to be_a(String)
              expect(data.size).to eq(16)
              expect(data[0]['attributes']['serviceName']).to eq('service_name')
              expect(data[0]['attributes']['physicalLocation']).to eq('physical_location')
              expect(data[0]['attributes']['location']).to eq(expected_facility)
              expect(response).to match_camelized_response_schema('vaos/v2/appointments', { strict: false })

              # Verify event logging was called with facility IDs extracted from visible appointments
              # Cassette has 16 appointments: 14 cancelled + 1 proposed (983) + 1 null status (983)
              # Only non-cancelled appointments are tracked, so we expect ['983']
              expect(UniqueUserEvents).to have_received(:log_event).with(
                user: anything,
                event_name: UniqueUserEvents::EventRegistry::APPOINTMENTS_ACCESSED,
                event_facility_ids: ['983']
              )
            end
          end

          it 'has access and returns cerner appointments and honors includes' do
            VCR.use_cassette('vaos/v2/appointments/get_appointments_200_booked_cerner_with_color1_location',
                             match_requests_on: %i[method path query], allow_playback_repeats: true) do
              allow(Rails.logger).to receive(:info).at_least(:once)
              allow_any_instance_of(VAOS::V2::MobileFacilityService).to receive(
                :get_facility
              ).and_return(mock_appt_location_openstruct)
              get '/vaos/v2/appointments?_include=facilities,clinics', params:, headers: inflection_header
              data = JSON.parse(response.body)['data']
              expect(response).to have_http_status(:ok)
              expect(response.body).to be_a(String)
              expect(data.size).to eq(1)
              expect(data[0]['attributes']['location']['attributes'].to_json).to eq(
                mock_appt_location_openstruct.table.to_json
              )
              expect(Rails.logger).to have_received(:info).with("Details for Cerner 'COL OR 1' Appointment",
                                                                any_args).at_least(:once)
              expect(response).to match_camelized_response_schema('vaos/v2/appointments', { strict: false })
            end
          end

          it 'iterates over appointment list and merges provider name for cc proposed' do
            VCR.use_cassette('vaos/v2/appointments/get_appointments_200_cc_proposed', match_requests_on: %i[method],
                                                                                      allow_playback_repeats: true) do
              allow_any_instance_of(VAOS::V2::MobilePPMSService).to \
                receive(:get_provider_with_cache).with('1528231610').and_return(provider_response2)
              get '/vaos/v2/appointments?_include=facilities,clinics' \
                  '&start=2022-09-13&end=2023-01-12&statuses[]=proposed',
                  headers: inflection_header
              data = JSON.parse(response.body)['data']

              expect(response).to have_http_status(:ok)
              expect(response.body).to be_a(String)
              expect(data[0]['attributes']['preferredProviderName']).to eq('CARLTON, ROBERT A')
              expect(response).to match_camelized_response_schema('vaos/v2/appointments', { strict: false })
            end
          end

          it 'has access and returns va appointments and honors includes with no physical_location field' do
            stub_facilities
            allow_any_instance_of(VAOS::V2::MobileFacilityService).to receive(:get_clinic)
              .and_return(mock_clinic_without_physical_location)
            VCR.use_cassette('vaos/v2/appointments/get_appointments_200_with_facilities_200',
                             match_requests_on: %i[method path query], allow_playback_repeats: true) do
              get '/vaos/v2/appointments?_include=facilities,clinics', params:, headers: inflection_header
              data = JSON.parse(response.body)['data']
              expect(response).to have_http_status(:ok)

              expect(data.size).to eq(16)
              expect(data[0]['attributes']['serviceName']).to eq('service_name')
              expect(data[0]['attributes']['location']).to eq(expected_facility)
              expect(response).to match_camelized_response_schema('vaos/v2/appointments', { strict: false })
            end
          end

          it 'has access and returns va appointments' do
            VCR.use_cassette('vaos/v2/appointments/get_appointments_200_with_facilities_200',
                             match_requests_on: %i[method path query], allow_playback_repeats: true) do
              get '/vaos/v2/appointments', params:, headers: inflection_header
              data = JSON.parse(response.body)['data']
              expect(response).to have_http_status(:ok)
              expect(response.body).to be_a(String)
              expect(data.size).to eq(16)
              expect(data[0]['attributes']['serviceName']).to be_nil
              expect(data[0]['attributes']['location']).to be_nil
              expect(response).to match_camelized_response_schema('vaos/v2/appointments', { strict: false })
            end
          end

          it 'returns va appointments and logs details when there is a PAP COMPLIANCE comment' do
            VCR.use_cassette('vaos/v2/appointments/get_appointments_200_with_facilities_200_and_log_pap_comp',
                             match_requests_on: %i[method path query], allow_playback_repeats: true) do
              allow(Rails.logger).to receive(:info).at_least(:once)
              get '/vaos/v2/appointments', params:, headers: inflection_header
              expect(response).to have_http_status(:ok)
              expect(response.body).to be_a(String)
              expect(Rails.logger).to have_received(:info).with('Details for PAP COMPLIANCE/TELE appointment',
                                                                match("GET '/vaos/v1/patients/<icn>/appointments'"))
                                                          .at_least(:once)
              expect(response).to match_camelized_response_schema('vaos/v2/appointments', { strict: false })
            end
          end

          it 'returns va appointments and logs CnP appointment count' do
            VCR.use_cassette('vaos/v2/appointments/get_appointments_200_with_facilities_200_and_log_cnp',
                             match_requests_on: %i[method path query], allow_playback_repeats: true) do
              allow(Rails.logger).to receive(:info)
              get '/vaos/v2/appointments', params:, headers: inflection_header
              expect(Rails.logger).to have_received(:info).with(
                'Compensation and Pension count on an appointment list retrieval', { CompPenCount: 2 }.to_json
              )
              expect(response).to have_http_status(:ok)
              expect(response.body).to be_a(String)
              expect(response).to match_camelized_response_schema('vaos/v2/appointments', { strict: false })
            end
          end

          it 'does not log cnp count of the returned appointments when there are no cnp appointments' do
            VCR.use_cassette('vaos/v2/appointments/get_appointments_200_with_facilities_200_and_log_pap_comp',
                             match_requests_on: %i[method path query], allow_playback_repeats: true) do
              allow(Rails.logger).to receive(:info)
              get '/vaos/v2/appointments', params:, headers: inflection_header
              expect(Rails.logger).not_to have_received(:info).with(
                'Compensation and Pension count on an appointment list retrieval', { CompPenCount: 0 }.to_json
              )
              expect(response).to have_http_status(:ok)
              expect(response.body).to be_a(String)
              expect(response).to match_camelized_response_schema('vaos/v2/appointments', { strict: false })
            end
          end

          it 'has access and returns a va appointments with no location id' do
            VCR.use_cassette('vaos/v2/appointments/get_appointments_200_no_location_id',
                             match_requests_on: %i[method path query], allow_playback_repeats: true) do
              get '/vaos/v2/appointments?_include=clinics', params:, headers: inflection_header
              data = JSON.parse(response.body)['data']
              expect(response).to have_http_status(:ok)
              expect(response.body).to be_a(String)
              expect(data.size).to eq(1)
              expect(data[0]['attributes']['serviceName']).to be_nil

              expect(response).to match_camelized_response_schema('vaos/v2/appointments', { strict: false })
            end
          end

          it 'has access and returns va appointments when systems service fails' do
            VCR.use_cassette('vaos/v2/appointments/get_appointments_200_with_system_service_500',
                             match_requests_on: %i[method path query], allow_playback_repeats: true) do
              get '/vaos/v2/appointments', params:, headers: inflection_header
              data = JSON.parse(response.body)['data']
              expect(response).to have_http_status(:ok)
              expect(response.body).to be_a(String)

              expect(data[0]['attributes']['serviceName']).to be_nil
              expect(response).to match_camelized_response_schema('vaos/v2/appointments', { strict: false })
            end
          end

          it 'has access and returns va appointments when mobile facility service fails' do
            VCR.use_cassette('vaos/v2/appointments/get_appointments_200_with_mobile_facility_service_500',
                             match_requests_on: %i[method path query], allow_playback_repeats: true) do
              get '/vaos/v2/appointments?_include=facilities', params:, headers: inflection_header
              data = JSON.parse(response.body)['data']
              expect(response).to have_http_status(:ok)
              expect(response.body).to be_a(String)
              expect(data.size).to eq(18)
              expect(data[0]['attributes']['location']).to eq(facility_error_msg)
              expect(data[17]['attributes']['location']).not_to eq(facility_error_msg)
              expect(response).to match_camelized_response_schema('vaos/v2/appointments', { strict: false })
            end
          end

          it 'has access and ensures no logging of facility details on mobile facility service fails' do
            VCR.use_cassette('vaos/v2/appointments/get_appointments_200_with_mobile_facility_service_500',
                             match_requests_on: %i[method path query], allow_playback_repeats: true) do
              allow(Rails.logger).to receive(:info)
              get '/vaos/v2/appointments?_include=facilities', params:, headers: inflection_header
              data = JSON.parse(response.body)['data']
              expect(response).to have_http_status(:ok)
              expect(response.body).to be_a(String)
              expect(data.size).to eq(18)
              expect(data[0]['attributes']['location']).to eq(facility_error_msg)
              expect(data[17]['attributes']['location']).not_to eq(facility_error_msg)
              expect(Rails.logger).not_to have_received(:info).with("Details for Cerner 'COL OR 1' Appointment",
                                                                    any_args)
              expect(response).to match_camelized_response_schema('vaos/v2/appointments', { strict: false })
            end
          end

          it 'has access and returns va appointments given a date range and single status' do
            VCR.use_cassette('vaos/v2/appointments/get_appointments_single_status_200',
                             match_requests_on: %i[method path query]) do
              get '/vaos/v2/appointments?start=2022-01-01T19:25:00Z&end=2022-12-01T19:45:00Z&statuses=proposed',
                  headers: inflection_header
              expect(response).to match_camelized_response_schema('vaos/v2/appointments', { strict: false })
              data = JSON.parse(response.body)['data']
              expect(data.size).to eq(4)
              expect(data[0]['attributes']['status']).to eq('proposed')
              expect(data[1]['attributes']['status']).to eq('proposed')
              expect(response).to match_camelized_response_schema('vaos/v2/va_appointments', { strict: false })
            end
          end

          it 'has access and returns va appointments given date a range and single status (as array)' do
            VCR.use_cassette('vaos/v2/appointments/get_appointments_single_status_200',
                             match_requests_on: %i[method path query]) do
              get '/vaos/v2/appointments?start=2022-01-01T19:25:00Z&end=2022-12-01T19:45:00Z&statuses[]=proposed',
                  headers: inflection_header
              expect(response).to match_camelized_response_schema('vaos/v2/appointments', { strict: false })
              data = JSON.parse(response.body)['data']
              expect(data.size).to eq(4)
              expect(data[0]['attributes']['status']).to eq('proposed')
              expect(data[1]['attributes']['status']).to eq('proposed')
              expect(response).to match_camelized_response_schema('vaos/v2/va_appointments', { strict: false })
            end
          end

          it 'has access and returns va appointments given a date range and multiple statuses' do
            VCR.use_cassette('vaos/v2/appointments/get_appointments_multi_status_200',
                             match_requests_on: %i[method path query]) do
              get '/vaos/v2/appointments?start=2022-01-01T19:25:00Z&end=2022-12-01T19:45:00Z&statuses=proposed,booked',
                  headers: inflection_header
              expect(response).to have_http_status(:ok)
              expect(response).to match_camelized_response_schema('vaos/v2/appointments', { strict: false })
              data = JSON.parse(response.body)['data']
              expect(data.size).to eq(2)
              expect(data[0]['attributes']['status']).to eq('proposed')
              expect(data[1]['attributes']['status']).to eq('booked')
              expect(response).to match_camelized_response_schema('vaos/v2/va_appointments', { strict: false })
            end
          end

          it 'has access and returns va appointments given a date range and multiple statuses (as Array)' do
            VCR.use_cassette('vaos/v2/appointments/get_appointments_multi_status_200',
                             match_requests_on: %i[method path query]) do
              get '/vaos/v2/appointments?start=2022-01-01T19:25:00Z&end=2022-12-01T19:45:00Z&statuses[]=proposed' \
                  '&statuses[]=booked',
                  headers: inflection_header
              expect(response).to have_http_status(:ok)
              expect(response).to match_camelized_response_schema('vaos/v2/appointments', { strict: false })
              data = JSON.parse(response.body)['data']
              expect(data.size).to eq(2)
              expect(data[0]['attributes']['status']).to eq('proposed')
              expect(data[1]['attributes']['status']).to eq('booked')
              expect(response).to match_camelized_response_schema('vaos/v2/va_appointments', { strict: false })
            end
          end

          it 'has access and returns va appointments having partial errors' do
            VCR.use_cassette('vaos/v2/appointments/get_appointments_v2_partial_error',
                             match_requests_on: %i[method path query]) do
              get '/vaos/v2/appointments?start=2022-01-01T19:25:00Z&end=2022-12-01T19:45:00Z&statuses[]=proposed',
                  params:, headers: inflection_header

              expect(response).to have_http_status(:multi_status)
              expect(response).to match_camelized_response_schema('vaos/v2/va_appointments', { strict: false })
            end
          end

          it 'returns a 400 error' do
            VCR.use_cassette('vaos/v2/appointments/get_appointments_400', match_requests_on: %i[method path query]) do
              get '/vaos/v2/appointments', params: { start: start_date }

              expect(response).to have_http_status(:bad_request)
              expect(JSON.parse(response.body)['errors'][0]['status']).to eq('400')
            end
          end
        end
      end
    end

    describe 'GET appointment' do
      context 'when the VAOS service returns a single appointment' do
        before do
          allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_use_vpg,
                                                    instance_of(User)).and_return(false)
          allow(Flipper).to receive(:enabled?).with('schema_contract_appointments_index').and_return(false)
          allow(Flipper).to receive(:enabled?).with(:travel_pay_view_claim_details,
                                                    instance_of(User)).and_return(false)
          allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_use_vpg).and_return(false)
        end

        let(:avs_path) do
          '/my-health/medical-records/summaries-and-notes/visit-summary/C46E12AA7582F5714716988663350853'
        end

        let(:avs_pdf) do
          [
            {
              'apptId' => '12345',
              'id' => '15249638961',
              'name' => 'Ambulatory Visit Summary',
              'loincCodes' => %w[4189669 96345-4],
              'noteType' => 'ambulatory_patient_summary',
              'contentType' => 'application/pdf'
            }
          ]
        end

        it 'has access and returns appointment - va proposed' do
          VCR.use_cassette('vaos/v2/appointments/get_appointment_200_with_facility_200',
                           match_requests_on: %i[method path query]) do
            allow(Rails.logger).to receive(:info).at_least(:once)
            allow_any_instance_of(VAOS::V2::AppointmentsService).to receive(:get_avs_link)
              .and_return(avs_path)
            get '/vaos/v2/appointments/70060', headers: inflection_header
            expect(response).to have_http_status(:ok)
            expect(json_body_for(response)).to match_camelized_schema('vaos/v2/appointment',
                                                                      { strict: false })
            data = JSON.parse(response.body)['data']

            expect(data['id']).to eq('70060')
            expect(data['attributes']['kind']).to eq('clinic')
            expect(data['attributes']['status']).to eq('proposed')
            expect(data['attributes']['pending']).to be(true)
            expect(data['attributes']['past']).to be(true)
            expect(data['attributes']['future']).to be(false)
            expect(data['attributes']['avsPath']).to be_nil
            expect(Rails.logger).to have_received(:info).with(
              'VAOS::V2::AppointmentsController appointment creation time: 2021-12-13T14:03:02Z',
              { created: '2021-12-13T14:03:02Z' }.to_json
            )
          end
        end

        it 'has access and returns appointment with avs included' do
          VCR.use_cassette('vaos/v2/appointments/get_appointment_200_with_facility_200_with_avs',
                           match_requests_on: %i[method path query]) do
            allow(Rails.logger).to receive(:info).at_least(:once)
            allow_any_instance_of(VAOS::V2::AppointmentsService).to receive(:get_avs_link)
              .and_return(avs_path)
            get '/vaos/v2/appointments/70060?_include=avs', headers: inflection_header
            expect(response).to have_http_status(:ok)
            expect(json_body_for(response)).to match_camelized_schema('vaos/v2/appointment', { strict: false })
            data = JSON.parse(response.body)['data']

            expect(data['id']).to eq('70060')
            expect(data['attributes']['kind']).to eq('clinic')
            expect(data['attributes']['status']).to eq('booked')
            expect(data['attributes']['avsPath']).to eq(avs_path)
            expect(Rails.logger).to have_received(:info).with(
              'VAOS::V2::AppointmentsController appointment creation time: 2021-12-13T14:03:02Z',
              { created: '2021-12-13T14:03:02Z' }.to_json
            )
          end
        end

        it 'has access and returns appointment with OH avs' do
          VCR.use_cassette('vaos/v2/appointments/get_appointment_200_with_facility_200_with_avs_cerner',
                           match_requests_on: %i[method path query]) do
            allow(Rails.logger).to receive(:info).at_least(:once)
            allow_any_instance_of(UnifiedHealthData::Service).to receive(:get_appt_avs).and_return(avs_pdf)
            get '/vaos/v2/appointments/70060?_include=avs', headers: inflection_header
            expect(response).to have_http_status(:ok)
            expect(json_body_for(response)).to match_camelized_schema('vaos/v2/appointment',
                                                                      { strict: false })
            data = JSON.parse(response.body)['data']

            expect(data['id']).to eq('70060')
            expect(data['attributes']['kind']).to eq('clinic')
            expect(data['attributes']['status']).to eq('booked')
            expect(data['attributes']['avsPdf']).to eq(avs_pdf)
            expect(Rails.logger).to have_received(:info).with(
              'VAOS::V2::AppointmentsController appointment creation time: 2021-12-13T14:03:02Z',
              { created: '2021-12-13T14:03:02Z' }.to_json
            )
          end
        end

        context 'with judy morrison test appointment' do
          let(:current_user) { build(:user, :vaos) }
          let(:avs_error) { 'Error retrieving AVS info' }

          it 'includes an avs error message in response when appointment has no available avs' do
            stub_clinics
            VCR.use_cassette('vaos/v2/appointments/get_appointment_200_no_avs',
                             match_requests_on: %i[method path query]) do
              allow(Rails.logger).to receive(:info).at_least(:once)
              get '/vaos/v2/appointments/192308', headers: inflection_header
              expect(response).to have_http_status(:ok)
              expect(json_body_for(response)).to match_camelized_schema('vaos/v2/appointment',
                                                                        { strict: false })
              data = JSON.parse(response.body)['data']

              expect(data['id']).to eq('192308')
              expect(data['attributes']['avsPath']).to be_nil
              expect(Rails.logger).to have_received(:info).with(
                'VAOS::V2::AppointmentsController appointment creation time: 2023-11-01T00:00:00Z',
                { created: '2023-11-01T00:00:00Z' }.to_json
              )
            end
          end
        end

        it 'has access and returns appointment - cc proposed' do
          VCR.use_cassette('vaos/v2/appointments/get_appointment_200_cc_proposed_with_facility_200',
                           match_requests_on: %i[method path query]) do
            allow_any_instance_of(VAOS::V2::MobilePPMSService).to \
              receive(:get_provider_with_cache).with('1407938061').and_return(provider_response)
            allow(Rails.logger).to receive(:info).at_least(:once)
            get '/vaos/v2/appointments/81063', headers: inflection_header
            expect(response).to have_http_status(:ok)
            expect(json_body_for(response)).to match_camelized_schema('vaos/v2/appointment',
                                                                      { strict: false })
            data = JSON.parse(response.body)['data']

            expect(data['id']).to eq('81063')
            expect(data['attributes']['kind']).to eq('cc')
            expect(data['attributes']['status']).to eq('proposed')
            expect(data['attributes']['preferredProviderName']).to eq('DEHGHAN, AMIR')
            expect(Rails.logger).to have_received(:info).with(
              'VAOS::V2::AppointmentsController appointment creation time: 2022-02-22T21:46:00Z',
              { created: '2022-02-22T21:46:00Z' }.to_json
            )
          end
        end

        it 'has access and returns appointment - cc booked' do
          VCR.use_cassette('vaos/v2/appointments/get_appointment_200_JACQUELINE_M_BOOKED_with_facility_200',
                           match_requests_on: %i[method path query]) do
            allow(Rails.logger).to receive(:info).at_least(:once)
            get '/vaos/v2/appointments/72106', headers: inflection_header
            expect(response).to have_http_status(:ok)
            expect(json_body_for(response)).to match_camelized_schema('vaos/v2/appointment',
                                                                      { strict: false })
            data = JSON.parse(response.body)['data']

            expect(data['id']).to eq('72106')
            expect(data['attributes']['kind']).to eq('cc')
            expect(data['attributes']['status']).to eq('booked')
            expect(Rails.logger).to have_received(:info).with(
              'VAOS::V2::AppointmentsController appointment creation time: 2022-01-10T22:02:08Z',
              { created: '2022-01-10T22:02:08Z' }.to_json
            )
          end
        end

        it 'updates the service name, physical location, and location' do
          stub_facilities
          allow_any_instance_of(VAOS::V2::MobileFacilityService).to receive(:get_clinic)
            .and_return(service_name: 'Service Name', physical_location: 'Physical Location')
          VCR.use_cassette('vaos/v2/appointments/get_appointment_200', match_requests_on: %i[method path query]) do
            allow(Rails.logger).to receive(:info).at_least(:once)

            get '/vaos/v2/appointments/70060', headers: inflection_header

            data = json_body_for(response)['attributes']
            expect(data['serviceName']).to eq('Service Name')
            expect(data['physicalLocation']).to eq('Physical Location')
            expect(data['location']).to eq(expected_facility)
            expect(Rails.logger).to have_received(:info).with(
              'VAOS::V2::AppointmentsController appointment creation time: 2021-12-13T14:03:02Z',
              { created: '2021-12-13T14:03:02Z' }.to_json
            )
          end
        end

        it 'displays telehealth link if current time is within lower boundary' do
          Timecop.freeze(DateTime.parse('2023-10-13T14:31:00Z'))

          stub_facilities
          allow_any_instance_of(VAOS::V2::MobileFacilityService).to receive(:get_clinic)
            .and_return(service_name: 'Service Name', physical_location: 'Physical Location')
          VCR.use_cassette('vaos/v2/appointments/get_appointment_200_with_telehealth_info',
                           match_requests_on: %i[method path query], allow_playback_repeats: true) do
            get '/vaos/v2/appointments/75105', headers: inflection_header
            expect(response).to have_http_status(:ok)
            data = json_body_for(response)['attributes']
            expect(data['telehealth']['displayLink']).to be(true)

            Timecop.unfreeze
          end
        end

        it 'hides telehealth link if current time is outside lower boundary' do
          Timecop.freeze(DateTime.parse('2023-10-13T14:29:00Z'))

          stub_facilities
          allow_any_instance_of(VAOS::V2::MobileFacilityService).to receive(:get_clinic)
            .and_return(service_name: 'Service Name', physical_location: 'Physical Location')
          VCR.use_cassette('vaos/v2/appointments/get_appointment_200_with_telehealth_info',
                           match_requests_on: %i[method path query], allow_playback_repeats: true) do
            get '/vaos/v2/appointments/75105', headers: inflection_header
            expect(response).to have_http_status(:ok)
            data = json_body_for(response)['attributes']
            expect(data['telehealth']['displayLink']).to be(false)

            Timecop.unfreeze
          end
        end

        it 'displays telehealth link if current time is within upper boundary' do
          Timecop.freeze(DateTime.parse('2023-10-13T19:00:00Z'))

          stub_facilities
          allow_any_instance_of(VAOS::V2::MobileFacilityService).to receive(:get_clinic)
            .and_return(service_name: 'Service Name', physical_location: 'Physical Location')
          VCR.use_cassette('vaos/v2/appointments/get_appointment_200_with_telehealth_info',
                           match_requests_on: %i[method path query], allow_playback_repeats: true) do
            get '/vaos/v2/appointments/75105', headers: inflection_header
            expect(response).to have_http_status(:ok)
            data = json_body_for(response)['attributes']
            expect(data['telehealth']['displayLink']).to be(true)

            Timecop.unfreeze
          end
        end

        it 'hides telehealth link if current time is outside upper boundary' do
          Timecop.freeze(DateTime.parse('2023-10-13T19:01:00Z'))

          stub_facilities
          allow_any_instance_of(VAOS::V2::MobileFacilityService).to receive(:get_clinic)
            .and_return(service_name: 'Service Name', physical_location: 'Physical Location')
          VCR.use_cassette('vaos/v2/appointments/get_appointment_200_with_telehealth_info',
                           match_requests_on: %i[method path query], allow_playback_repeats: true) do
            get '/vaos/v2/appointments/75105', headers: inflection_header
            expect(response).to have_http_status(:ok)
            data = json_body_for(response)['attributes']
            expect(data['telehealth']['displayLink']).to be(false)

            Timecop.unfreeze
          end
        end

        it 'returns an eps appointment' do
          VCR.use_cassette('vaos/eps/token/token_200', match_requests_on: %i[method path]) do
            VCR.use_cassette('vaos/eps/get_appointment/booked_200', match_requests_on: %i[method path]) do
              get '/vaos/v2/appointments/qdm61cJ5?_include=eps', headers: inflection_header

              expect(response).to have_http_status(:success)
              body = JSON.parse(response.body)

              expect(body).to include('data')
              expect(body['data']).to include('id', 'type', 'attributes')
              expect(body['data']['attributes']).to include(
                'id', 'state', 'patientId', 'referral',
                'providerServiceId', 'networkId', 'slotIds',
                'appointmentDetails'
              )
            end
          end
        end
      end

      context 'when the VAOS service errors on retrieving an appointment' do
        before do
          allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_use_vpg,
                                                    instance_of(User)).and_return(false)
          allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_vaos_alternate_route).and_return(false)
        end

        it 'returns a 502 status code' do
          VCR.use_cassette('vaos/v2/appointments/get_appointment_500', match_requests_on: %i[method path query]) do
            vamf_url = 'https://veteran.apps.va.gov/vaos/v1/patients/' \
                       'd12672eba61b7e9bc50bb6085a0697133a5fbadf195e6cade452ddaad7921c1d/appointments/00000'
            get '/vaos/v2/appointments/00000'
            body = JSON.parse(response.body)

            expect(response).to have_http_status(:bad_gateway)
            expect(body.dig('errors', 0, 'code')).to eq('VAOS_502')
            expect(body.dig('errors', 0, 'source', 'vamf_url')).to eq(vamf_url)
          end
        end
      end

      context 'when the EPS service errors on retrieving an appointment' do
        before do
          allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_use_vpg,
                                                    instance_of(User)).and_return(false)
          allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_vaos_alternate_route).and_return(false)
        end

        it 'returns a 502 status code' do
          VCR.use_cassette('vaos/eps/token/token_200', match_requests_on: %i[method path]) do
            VCR.use_cassette('vaos/eps/get_appointment/500', match_requests_on: %i[method path]) do
              vamf_url = 'https://api.wellhive.com/care-navigation/v1/appointments/qdm61cJ5?retrieveLatestDetails=true'
              get '/vaos/v2/appointments/qdm61cJ5?_include=eps', headers: inflection_header
              expect(response).to have_http_status(:bad_gateway)
              body = JSON.parse(response.body)

              expect(body.dig('errors', 0, 'code')).to eq('VAOS_502')
              expect(body.dig('errors', 0, 'source', 'vamfUrl')).to eq(vamf_url)
            end
          end
        end
      end
    end

    describe 'PUT appointments' do
      context 'when the appointment is successfully cancelled' do
        before do
          allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_use_vpg,
                                                    instance_of(User)).and_return(false)
        end

        it 'returns a status code of 200 and the cancelled appointment with the updated status' do
          stub_facilities
          stub_clinics
          VCR.use_cassette('vaos/v2/appointments/cancel_appointments_200', match_requests_on: %i[method path query]) do
            put '/vaos/v2/appointments/70060', params: { status: 'cancelled' }, headers: inflection_header
            expect(response).to have_http_status(:success)
            json_body = json_body_for(response)
            expect(json_body).to match_camelized_schema('vaos/v2/appointment', { strict: false })
            expect(json_body.dig('attributes', 'status')).to eq('cancelled')

            expect(json_body.dig('attributes', 'location', 'timezone', 'timeZoneId')).to eq('America/New_York')
            expect(json_body.dig('attributes', 'requestedPeriods', 0, 'localStartTime'))
              .to eq('2021-12-19T19:00:00.000-05:00')
          end
        end

        context 'when clinic and location_id are present' do
          it 'updates the service name, physical location, and location' do
            allow_any_instance_of(VAOS::V2::MobileFacilityService).to receive(:get_clinic)
              .and_return(service_name: 'Service Name', physical_location: 'Physical Location')
            stub_facilities
            VCR.use_cassette('vaos/v2/appointments/cancel_appointments_200',
                             match_requests_on: %i[method path query]) do
              put '/vaos/v2/appointments/70060', params: { status: 'cancelled' }, headers: inflection_header

              data = json_body_for(response)['attributes']
              expect(data['serviceName']).to eq('Service Name')
              expect(data['physicalLocation']).to eq('Physical Location')
              expect(data['location']).to eq(expected_facility)
            end
          end
        end

        it 'returns a 400 status code' do
          allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_use_vpg).and_return(false)
          VCR.use_cassette('vaos/v2/appointments/cancel_appointment_400', match_requests_on: %i[method path query]) do
            put '/vaos/v2/appointments/42081', params: { status: 'cancelled' }
            expect(response).to have_http_status(:bad_request)
            expect(JSON.parse(response.body)['errors'][0]['code']).to eq('VAOS_400')
          end
        end
      end

      context 'when the backend service cannot handle the request' do
        before do
          allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_use_vpg,
                                                    instance_of(User)).and_return(false)
        end

        it 'returns a 502 status code' do
          VCR.use_cassette('vaos/v2/appointments/cancel_appointment_500',
                           match_requests_on: %i[method path query]) do
            put '/vaos/v2/appointments/35952', params: { status: 'cancelled' }
            expect(response).to have_http_status(:bad_gateway)
            expect(JSON.parse(response.body)['errors'][0]['code']).to eq('VAOS_502')
          end
        end
      end
    end

    describe 'POST appointments/submit' do
      before do
        allow(Rails).to receive(:cache).and_return(memory_store)
        Rails.cache.clear

        allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_use_vpg).and_return(false)
      end

      context 'referral appointment' do
        let(:params) do
          { referral_number: '12345',
            provider_service_id: '9mN718pH',
            id: 'J9BhspdR',
            slot_id: '5vuTac8v-practitioner-4-role-1|2a82f6c9-e693-4091-826d' \
                     '-97b392958301|2024-11-04T17:00:00Z|30m0s|1732735998236|ov',
            network_id: 'sandbox-network-5vuTac8v',
            name: {
              family: 'Smith',
              given: %w[
                Sarah
                Elizabeth
              ]
            },
            birth_date: '1985-03-15',
            email: 'sarah.smith@email.com',
            gender: 'female',
            phone_number: '407-555-8899',
            address: {
              city: 'Orlando',
              country: 'USA',
              line: [
                '742 Sunshine Boulevard',
                'Apt 15B'
              ],
              postal_code: '32801',
              state: 'FL',
              type: 'both',
              text: 'text'
            } }
        end
        let(:memory_store) { ActiveSupport::Cache.lookup_store(:memory_store) }

        it 'successfully submits referral appointment' do
          VCR.use_cassette('vaos/v2/eps/post_access_token',
                           match_requests_on: %i[method path]) do
            VCR.use_cassette('vaos/v2/eps/post_submit_appointment',
                             match_requests_on: %i[method path body]) do
              allow(StatsD).to receive(:increment).with(any_args)
              allow(StatsD).to receive(:histogram).with(any_args)

              expect(StatsD).to receive(:increment).with(
                described_class::APPT_CREATION_SUCCESS_METRIC,
                tags: ['service:community_care_appointments', 'type_of_care:no_value']
              )

              post '/vaos/v2/appointments/submit', params:, headers: inflection_header

              response_obj = JSON.parse(response.body)
              expect(response).to have_http_status(:created)
              expect(response_obj.dig('data', 'id')).to eql('J9BhspdR')
            end
          end
        end

        it 'submits referral appointment with conflict error' do
          VCR.use_cassette('vaos/v2/eps/post_access_token',
                           match_requests_on: %i[method path]) do
            VCR.use_cassette('vaos/v2/eps/post_submit_appointment_conflict',
                             match_requests_on: %i[method path body]) do
              expect_metric_increment(described_class::APPT_CREATION_FAILURE_METRIC) do
                post '/vaos/v2/appointments/submit', params:, headers: inflection_header
              end

              response_obj = JSON.parse(response.body)
              expect(response).to have_http_status(:conflict)
              error = response_obj['errors'][0]
              expect(error['title']).to eql('Appointment creation failed')
              expect(error['detail']).to eql('Could not create appointment')
            end
          end
        end

        it 'records success metrics when submitting referral appointment' do
          VCR.use_cassette('vaos/v2/eps/post_access_token',
                           match_requests_on: %i[method path]) do
            VCR.use_cassette('vaos/v2/eps/post_submit_appointment',
                             match_requests_on: %i[method path body]) do
              Timecop.freeze(Time.current) do
                # mimic caching of referral data that occurs when the referral object is created
                # earlier in the appointment creation process
                referral = Ccra::ReferralDetail.new(
                  referral_number: params[:referral_number],
                  category_of_care: 'CARDIOLOGY',
                  treating_facility: 'VA Medical Center',
                  referral_date: Time.current.strftime('%Y-%m-%d'),
                  station_id: '528A6',
                  treating_provider_info: {
                    provider_name: 'Dr. Smith',
                    provider_npi: '9mN718pH'
                  }
                )
                Rails.cache.clear
                client = Ccra::RedisClient.new

                client.save_referral_data(
                  id: params[:referral_number],
                  icn: current_user.icn,
                  referral_data: referral
                )

                client.save_booking_start_time(
                  referral_number: params[:referral_number],
                  booking_start_time: Time.current.to_f
                )

                Timecop.travel(5.seconds.from_now)

                allow(StatsD).to receive(:increment).with(any_args)
                allow(StatsD).to receive(:histogram).with(any_args)

                post '/vaos/v2/appointments/submit', params:, headers: inflection_header
                expect(response).to have_http_status(:created)

                expect(StatsD).to have_received(:increment).with(
                  described_class::APPT_CREATION_SUCCESS_METRIC,
                  tags: ['service:community_care_appointments', 'type_of_care:CARDIOLOGY']
                )
                expect(StatsD).to have_received(:histogram).with(described_class::APPT_CREATION_DURATION_METRIC,
                                                                 kind_of(Numeric),
                                                                 tags: ['service:community_care_appointments'])
              end
            end
          end
        end

        it 'still submits appointment even when type of care retrieval fails' do
          VCR.use_cassette('vaos/v2/eps/post_access_token',
                           match_requests_on: %i[method path]) do
            VCR.use_cassette('vaos/v2/eps/post_submit_appointment',
                             match_requests_on: %i[method path body]) do
              # Mock cache to fail when retrieving referral data for metrics
              allow_any_instance_of(Ccra::ReferralService).to receive(:get_cached_referral_data)
                .and_raise(Redis::BaseError, 'Cache unavailable')

              allow(StatsD).to receive(:increment).with(any_args)
              allow(StatsD).to receive(:histogram).with(any_args)

              post '/vaos/v2/appointments/submit', params:, headers: inflection_header

              # Verify submission succeeded despite cache failure
              response_obj = JSON.parse(response.body)
              expect(response).to have_http_status(:created)
              expect(response_obj.dig('data', 'id')).to eql('J9BhspdR')

              # Verify metric was logged with 'no_value'
              expect(StatsD).to have_received(:increment).with(
                described_class::APPT_CREATION_SUCCESS_METRIC,
                tags: ['service:community_care_appointments', 'type_of_care:no_value']
              )
            end
          end
        end

        it 'handles EPS error response' do
          VCR.use_cassette('vaos/v2/eps/post_access_token',
                           match_requests_on: %i[method path]) do
            VCR.use_cassette('vaos/v2/eps/post_submit_appointment_400',
                             match_requests_on: %i[method path]) do
              expect_metric_increment(described_class::APPT_CREATION_FAILURE_METRIC) do
                post '/vaos/v2/appointments/submit', params: { ** params, phone_number: nil },
                                                     headers: inflection_header
              end

              response_obj = JSON.parse(response.body)
              expect(response).to have_http_status(:bad_request)
              error = response_obj['errors'][0]
              expect(error['detail']).to eql('Could not create appointment')
              expect(error['meta']).to include(
                'code' => 400,
                'originalDetail' => 'missing patient attributes: phone'
              )
              expect(error['meta']['originalError']).to include('BackendServiceException')
            end
          end
        end

        it 'records failure metric when appointment submission fails' do
          VCR.use_cassette('vaos/v2/eps/post_access_token',
                           match_requests_on: %i[method path]) do
            VCR.use_cassette('vaos/v2/eps/post_submit_appointment_500',
                             match_requests_on: %i[method path]) do
              allow(StatsD).to receive(:increment).with(any_args)

              expect(StatsD).to receive(:increment).with(
                described_class::APPT_CREATION_FAILURE_METRIC,
                tags: ['service:community_care_appointments', 'type_of_care:no_value']
              )

              post '/vaos/v2/appointments/submit', params:, headers: inflection_header

              expect(response).to have_http_status(:bad_gateway)
              response_obj = JSON.parse(response.body)
              expect(response_obj['errors']).to be_an(Array)
              error = response_obj['errors'][0]

              expect(error).to include(
                'title' => 'Appointment creation failed',
                'detail' => 'Could not create appointment'
              )

              expect(error['meta']).to include(
                'code' => 500,
                'backendResponse' => '{"isFault": true,"isTemporary": true,"name": "Internal Server Error"}'
              )

              expect(error['meta']['originalError']).to include('BackendServiceException')
              expect(error['meta']['originalError']).to include('vamf_url')
              expect(error['meta']['originalError']).to include('VAOS_502')
            end
          end
        end
      end
    end

    describe 'GET avs_binaries' do
      context 'with appointment having AVS documents' do
        let(:avs_binary) do
          UnifiedHealthData::BinaryData.new(
            content_type: 'application/pdf',
            binary: 'binaryString'
          )
        end

        it 'has access and returns appointment with OH avs' do
          allow_any_instance_of(UnifiedHealthData::Service).to receive(:get_avs_binary_data)
            .with(doc_id: 'doc0', appt_id: 'appt123').and_return(avs_binary)
          allow_any_instance_of(UnifiedHealthData::Service).to receive(:get_avs_binary_data)
            .with(doc_id: 'doc1', appt_id: 'appt123')
            .and_raise(Common::Exceptions::BackendServiceException)
          allow_any_instance_of(UnifiedHealthData::Service).to receive(:get_avs_binary_data)
            .with(doc_id: 'doc2', appt_id: 'appt123').and_return(nil)
          get '/vaos/v2/appointments/avs_binaries/appt123?doc_ids=doc0,doc1,doc2', headers: inflection_header
          expect(response).to have_http_status(:ok)
          # expect(json_body_for(response)).to match_camelized_schema('vaos/v2/appointment', { strict: false })
          data = JSON.parse(response.body)['data']
          expect(data.length).to eq(3)

          doc0 = data[0]
          expect(doc0['id']).to eq('doc0')
          expect(doc0['type']).to eq('avs_binary')

          doc0_attributes = doc0['attributes']
          expect(doc0_attributes['docId']).to eq('doc0')
          expect(doc0_attributes['binary']).to eq('binaryString')
          expect(doc0_attributes['error']).to be_nil

          doc1_attributes = data[1]['attributes']
          expect(doc1_attributes['docId']).to eq('doc1')
          expect(doc1_attributes['binary']).to be_nil
          expect(doc1_attributes['error']).to eq('Error retrieving AVS binary')

          doc2_attributes = data[2]['attributes']
          expect(doc2_attributes['docId']).to eq('doc2')
          expect(doc2_attributes['binary']).to be_nil
          expect(doc2_attributes['error']).to eq('Retrieved empty AVS binary')
        end
      end
    end
  end

  context 'for eps referrals' do
    let(:current_user) { build(:user, :vaos, icn: 'care-nav-patient-casey') }
    let(:memory_store) { ActiveSupport::Cache.lookup_store(:memory_store) }
    let(:redis_token_expiry) { 59.minutes }
    let(:npi) { '7894563210' }
    let(:specialty) { 'Urology' }
    let(:appointment_type_id) { 'ov' }
    let(:start_date) { '2025-01-01T00:00:00Z' }
    let(:end_date) { '2025-01-03T00:00:00Z' }
    let(:address) do
      {
        street1: '2184 E Irlo Bronson',
        city: 'Kissimmee',
        state: 'FL',
        zip: '34744-4415'
      }
    end
    let(:referral_data) do
      {
        provider_specialty: specialty,
        referral_number: 'ref-123',
        referral_consult_id: '123-123456',
        npi:,
        start_date:,
        end_date:,
        treating_facility_address: address
      }
    end

    let(:draft_params) do
      {
        referral_number: referral_data[:referral_number],
        referral_consult_id: referral_data[:referral_consult_id]
      }
    end

    let(:referral_identifiers) do
      {
        data: {
          id: draft_params[:referral_number],
          type: :referral_identifier,
          attributes: { npi:, appointment_type_id:, start_date:, end_date: }
        }
      }.to_json
    end

    before do
      allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_use_vpg, instance_of(User)).and_return(false)
      allow(Flipper).to receive(:enabled?).with('schema_contract_appointments_index').and_return(true)
      Timecop.freeze(DateTime.parse('2021-09-02T14:00:00Z'))

      allow(Rails).to receive(:cache).and_return(memory_store)
      Rails.cache.clear
    end

    describe 'POST create_draft' do
      context 'when the request is successful' do
        let(:draft_appointment_response) do
          {
            id: 'EEKoGzEf',
            state: 'draft',
            patientId: 'ref-123'
          }
        end

        let(:provider) do
          {
            'id' => 'Aq7wgAux',
            'name' => 'Dr. Monty Graciano @ FHA Kissimmee Medical Campus',
            'isActive' => true,
            'individualProviders' => [
              {
                'name' => 'Dr. Monty Graciano',
                'npi' => '7894563210'
              }
            ],
            'providerOrganization' => {
              'name' => 'Meridian Health (Sandbox 5vuTac8v)'
            },
            'location' => {
              'name' => 'FHA Kissimmee Medical Campus',
              'address' => '2184 E Irlo Bronson, Kissimmee, FL, 34744-4415, US',
              'latitude' => 28.30468,
              'longitude' => -81.41667,
              'timezone' => 'America/New_York'
            },
            'networkIds' => ['sandbox-network-5vuTac8v'],
            'schedulingNotes' => 'Age Limitations: This provider does not see patients 60 years or older.',
            'appointmentTypes' => [
              {
                'id' => 'ov',
                'name' => 'Office Visit',
                'isSelfSchedulable' => true
              }
            ],
            'specialties' => [
              {
                'id' => '208800000X',
                'name' => 'Urology'
              }
            ],
            'visitMode' => 'in-person',
            'features' => {
              'isDigital' => true,
              'directBooking' => {
                'isEnabled' => true,
                'requiredFields' => %w[phone address name birthdate gender]
              }
            }
          }
        end

        let(:slots_response) do
          {
            'count' => 2,
            'slots' => [
              {
                'id' => '5vuTac8v-practitioner-1-role-2|e43a19a8-b0cb-4dcf-befa-8cc511c3999b|' \
                        '2025-01-02T11:00:00Z|30m0s|1736636444704|ov',
                'providerServiceId' => '9mN718pH',
                'appointmentTypeId' => 'ov',
                'start' => '2025-01-02T11:00:00Z',
                'remaining' => 1
              },
              {
                'id' => '5vuTac8v-practitioner-1-role-2|e43a19a8-b0cb-4dcf-befa-8cc511c3999b|' \
                        '2025-01-02T15:30:00Z|30m0s|1736636444704|ov',
                'providerServiceId' => '9mN718pH',
                'appointmentTypeId' => 'ov',
                'start' => '2025-01-02T15:30:00Z',
                'remaining' => 1
              }
            ]
          }
        end

        let(:drive_times_response) do
          {
            'origin' => {
              'latitude' => 40.7128,
              'longitude' => -74.006
            },
            'destination' => {
              'distanceInMiles' => 313,
              'driveTimeInSecondsWithoutTraffic' => 19_096,
              'driveTimeInSecondsWithTraffic' => 19_561,
              'latitude' => 44.475883,
              'longitude' => -73.212074
            }
          }
        end

        let(:expected_response) do
          {
            'data' => {
              'id' => draft_appointment_response[:id],
              'type' => 'draft_appointment',
              'attributes' => {
                'provider' => provider,
                'slots' => slots_response['slots'],
                'drivetime' => drive_times_response
              }
            }
          }
        end

        it 'increments the success metric and returns a successful response when all calls succeed' do
          VCR.use_cassette('vaos/ccra/post_get_referral_ref_123', match_requests_on: %i[method path]) do
            VCR.use_cassette('vaos/v2/appointments/get_appointments_200', match_requests_on: %i[method path]) do
              VCR.use_cassette 'vaos/eps/token/token_200', match_requests_on: %i[method path] do
                VCR.use_cassette('vaos/eps/get_appointments/200_with_referral_number_no_appointments',
                                 match_requests_on: %i[method path]) do
                  VCR.use_cassette('vaos/eps/search_provider_services/200', match_requests_on: %i[method path]) do
                    VCR.use_cassette('vaos/eps/get_provider_slots/200', match_requests_on: %i[method path]) do
                      VCR.use_cassette('vaos/eps/get_drive_times/200', match_requests_on: %i[method path]) do
                        VCR.use_cassette('vaos/eps/draft_appointment/200', match_requests_on: %i[method path]) do
                          allow(StatsD).to receive(:increment).with(any_args)

                          expect(StatsD).to receive(:increment)
                            .with('api.vaos.appointment_draft_creation.success',
                                  tags: ['service:community_care_appointments', 'type_of_care:UROLOGY'])
                            .once

                          expect(StatsD).to receive(:increment)
                            .with('api.vaos.referral_draft_station_id.access',
                                  tags: [
                                    'service:community_care_appointments',
                                    'referring_facility_code:528A6',
                                    'station_id:528A6',
                                    'type_of_care:UROLOGY'
                                  ])
                            .once

                          expect(StatsD).to receive(:increment)
                            .with('api.vaos.provider_draft_network_id.access',
                                  tags: [
                                    'service:community_care_appointments',
                                    'network_id:sandbox-network-5vuTac8v'
                                  ])
                            .once

                          post '/vaos/v2/appointments/draft', params: draft_params, headers: inflection_header
                          expect(response).to have_http_status(:created)
                          expect(JSON.parse(response.body)).to eq(expected_response)
                        end
                      end
                    end
                  end
                end
              end
            end
          end
        end
      end

      context 'when appointment creation fails' do
        it 'returns appropriate error response when draft appointment creation fails' do
          VCR.use_cassette('vaos/ccra/post_get_referral_ref_123', match_requests_on: %i[method path]) do
            VCR.use_cassette('vaos/v2/appointments/get_appointments_200', match_requests_on: %i[method path]) do
              VCR.use_cassette('vaos/eps/get_drive_times/200', match_requests_on: %i[method path]) do
                VCR.use_cassette 'vaos/eps/get_provider_slots/200', match_requests_on: %i[method path] do
                  VCR.use_cassette('vaos/eps/search_provider_services/200', match_requests_on: %i[method path]) do
                    VCR.use_cassette 'vaos/eps/draft_appointment/500_internal_server_error',
                                     match_requests_on: %i[method path] do
                      VCR.use_cassette 'vaos/eps/token/token_200', match_requests_on: %i[method path] do
                        VCR.use_cassette('vaos/eps/get_appointments/200_with_referral_number_no_appointments',
                                         match_requests_on: %i[method path]) do
                          expect_metric_increment(described_class::APPT_DRAFT_CREATION_FAILURE_METRIC) do
                            post '/vaos/v2/appointments/draft', params: draft_params, headers: inflection_header
                          end

                          expect(response).to have_http_status(:bad_gateway)
                          response_obj = JSON.parse(response.body)
                          expect(response_obj).to have_key('errors')
                          expect(response_obj['errors']).to be_an(Array)
                          error = response_obj['errors'].first
                          expect(error['title']).to eq('Appointment creation failed')
                          expect(error['detail']).to eq('Could not create appointment')
                          expect(error['meta']).to include(
                            'code' => 500,
                            'backendResponse' => '{"isFault": true,"isTemporary": true,"name": "Internal Server Error"}'
                          )
                          expect(error['meta']['originalError']).to include('BackendServiceException')
                          expect(error['meta']['originalError']).to include('vamf_url')
                          expect(error['meta']['originalError']).to include('VAOS_502')
                        end
                      end
                    end
                  end
                end
              end
            end
          end
        end
      end

      context 'when drive time coords are invalid' do
        it 'handles invalid_range response' do
          VCR.use_cassette('vaos/ccra/post_get_referral_ref_123', match_requests_on: %i[method path]) do
            VCR.use_cassette('vaos/v2/appointments/get_appointments_200', match_requests_on: %i[method path]) do
              VCR.use_cassette 'vaos/eps/get_drive_times/400_invalid_coords', match_requests_on: %i[method path] do
                VCR.use_cassette 'vaos/eps/get_provider_slots/200', match_requests_on: %i[method path] do
                  VCR.use_cassette 'vaos/eps/search_provider_services/200', match_requests_on: %i[method path] do
                    VCR.use_cassette 'vaos/eps/draft_appointment/200', match_requests_on: %i[method path] do
                      VCR.use_cassette 'vaos/eps/token/token_200', match_requests_on: %i[method path] do
                        VCR.use_cassette('vaos/eps/get_appointments/200_with_referral_number_no_appointments',
                                         match_requests_on: %i[method path]) do
                          expect_metric_increment(described_class::APPT_DRAFT_CREATION_FAILURE_METRIC) do
                            post '/vaos/v2/appointments/draft', params: draft_params
                          end

                          expect(response).to have_http_status(:bad_request)
                          response_obj = JSON.parse(response.body)
                          expect(response_obj).to have_key('errors')
                          expect(response_obj['errors']).to be_an(Array)
                          error = response_obj['errors'].first
                          expect(error['title']).to eq('Appointment creation failed')
                          expect(error['detail']).to eq('Could not create appointment')
                          expect(error['meta']).to include(
                            'original_detail' => 'body.latitude must be lesser or equal than 90 but got value 91'
                          )
                        end
                      end
                    end
                  end
                end
              end
            end
          end
        end
      end

      context 'when provider is not found' do
        let(:invalid_provider_id) { '9mN718pHa' }

        before do
          updated_referral_identifiers = {
            data: {
              id: draft_params[:referral_number],
              type: :referral_identifier,
              attributes: { npi: invalid_provider_id, appointment_type_id:, start_date:, end_date: }
            }
          }.to_json

          Rails.cache.write(
            "vaos_eps_referral_identifier_#{draft_params[:referral_number]}",
            updated_referral_identifiers,
            namespace: 'eps-access-token',
            expires_in: redis_token_expiry
          )
        end

        it 'returns correct error status for provider not found' do
          allow(Rails.logger).to receive(:error)
          VCR.use_cassette('vaos/ccra/post_get_referral_ref_123', match_requests_on: %i[method path]) do
            VCR.use_cassette('vaos/v2/appointments/get_appointments_200', match_requests_on: %i[method path]) do
              VCR.use_cassette 'vaos/eps/search_provider_services/empty_200', match_requests_on: %i[method path] do
                VCR.use_cassette 'vaos/eps/token/token_200', match_requests_on: %i[method path] do
                  VCR.use_cassette('vaos/eps/get_appointments/200_with_referral_number_no_appointments',
                                   match_requests_on: %i[method path]) do
                    expect_metric_increment(described_class::APPT_DRAFT_CREATION_FAILURE_METRIC) do
                      post '/vaos/v2/appointments/draft', params: draft_params
                    end

                    # Verify the log was called with controller name set by BaseController's before_action
                    # The controller name and station_number prove the RequestStore mechanism works correctly
                    # Verify controller name comes from RequestStore (set by controller's before_action)
                    expected_controller_name = 'VAOS::V2::AppointmentsController'
                    # Verify station_number comes from user object
                    expected_station_number = current_user.va_treatment_facility_ids&.first

                    expect(Rails.logger).to have_received(:error).with(
                      'Community Care Appointments: Provider not found while creating draft appointment',
                      {
                        error_message: 'Provider not found while creating draft appointment',
                        user_uuid: current_user.uuid,
                        controller: expected_controller_name,
                        station_number: expected_station_number,
                        eps_trace_id: 'c9182a0e90280e7cc9ea83a192c1b787'
                      }
                    )

                    expect(response).to have_http_status(:not_found)
                    response_obj = JSON.parse(response.body)
                    expect(response_obj).to have_key('errors')
                    expect(response_obj['errors']).to be_an(Array)
                    error = response_obj['errors'].first
                    expect(error['title']).to eq('Appointment creation failed')
                    expect(error['detail']).to eq('Provider not found')
                  end
                end
              end
            end
          end
        end

        it 'returns correct error status when providers are returned but none are self-schedulable' do
          captured = []
          allow(Rails.logger).to receive(:error) { |msg, ctx| captured << [msg, ctx] }
          VCR.use_cassette('vaos/ccra/post_get_referral_ref_123', match_requests_on: %i[method path]) do
            VCR.use_cassette('vaos/v2/appointments/get_appointments_200', match_requests_on: %i[method path]) do
              VCR.use_cassette 'vaos/eps/search_provider_services/no_self_schedulable_200',
                               match_requests_on: %i[method path] do
                VCR.use_cassette 'vaos/eps/token/token_200', match_requests_on: %i[method path] do
                  VCR.use_cassette('vaos/eps/get_appointments/200_with_referral_number_no_appointments',
                                   match_requests_on: %i[method path]) do
                    expect_metric_increment(described_class::APPT_DRAFT_CREATION_FAILURE_METRIC) do
                      post '/vaos/v2/appointments/draft', params: draft_params
                    end

                    expect(response).to have_http_status(:not_found)
                    response_obj = JSON.parse(response.body)
                    expect(response_obj).to have_key('errors')
                    expect(response_obj['errors']).to be_an(Array)
                    error = response_obj['errors'].first
                    expect(error['title']).to eq('Appointment creation failed')
                    expect(error['detail']).to eq('Provider not found')

                    # Verify controller name comes from RequestStore (set by controller's before_action)
                    expected_controller_name = 'VAOS::V2::AppointmentsController'
                    # Verify station_number comes from user object
                    expected_station_number = current_user.va_treatment_facility_ids&.first

                    expect(Rails.logger).to have_received(:error).with(
                      'Community Care Appointments: No self-schedulable providers found for NPI',
                      {
                        controller: expected_controller_name,
                        station_number: expected_station_number,
                        eps_trace_id: 'c9182a0e90280e7cc9ea83a192c1b787',
                        user_uuid: current_user.uuid
                      }
                    )
                  end
                end
              end
            end
          end
        end
      end

      context 'when patient id is invalid' do
        it 'handles invalid patientId response as 400' do
          captured = []
          allow(Rails.logger).to receive(:error) { |msg, ctx| captured << [msg, ctx] }
          VCR.use_cassette('vaos/ccra/post_get_referral_ref_123', match_requests_on: %i[method path]) do
            VCR.use_cassette('vaos/v2/appointments/get_appointments_200', match_requests_on: %i[method path]) do
              VCR.use_cassette 'vaos/eps/get_provider_slots/200', match_requests_on: %i[method path] do
                VCR.use_cassette('vaos/eps/search_provider_services/200', match_requests_on: %i[method path]) do
                  VCR.use_cassette 'vaos/eps/draft_appointment/400_invalid_patientid',
                                   match_requests_on: %i[method path] do
                    VCR.use_cassette 'vaos/eps/token/token_200', match_requests_on: %i[method path] do
                      VCR.use_cassette('vaos/eps/get_appointments/200_with_referral_number_no_appointments',
                                       match_requests_on: %i[method path]) do
                        expect_metric_increment(described_class::APPT_DRAFT_CREATION_FAILURE_METRIC) do
                          post '/vaos/v2/appointments/draft', params: draft_params
                        end

                        expect(response).to have_http_status(:bad_request)
                        response_obj = JSON.parse(response.body)
                        expect(response_obj).to have_key('errors')
                        expect(response_obj['errors']).to be_an(Array)
                        error = response_obj['errors'].first
                        expect(error['title']).to eq('Appointment creation failed')
                        expect(error['detail']).to eq('Could not create appointment')
                        expect(error['meta']).to include(
                          'original_detail' => 'invalid patientId'
                        )

                        # Assert EXACTLY what our EPS logging emitted
                        # Verify controller name comes from RequestStore (set by controller's before_action)
                        expected_controller_name = 'VAOS::V2::AppointmentsController'
                        # Verify station_number comes from user object
                        expected_station_number = current_user.va_treatment_facility_ids&.first

                        expect(Rails.logger).to have_received(:error).with(
                          'Community Care Appointments: EPS service error',
                          {
                            service: 'EPS',
                            method: 'create_draft_appointment',
                            error_class: 'Eps::ServiceException',
                            timestamp: a_string_matching(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z/),
                            controller: expected_controller_name,
                            station_number: expected_station_number,
                            eps_trace_id: 'f2febe1c93219db9e208a8f1422d1d04',
                            code: 'VAOS_400',
                            upstream_status: 400,
                            upstream_body: a_string_including('invalid patientId')
                          }
                        )
                      end
                    end
                  end
                end
              end
            end
          end
        end
      end

      context 'when there is already an appointment associated with the referral' do
        it 'fails if a vaos appointment with the given referral id already exists' do
          draft_params[:referral_number] = 'ref-124'
          VCR.use_cassette('vaos/v2/appointments/get_appointments_200',
                           match_requests_on: %i[method path query], allow_playback_repeats: true, tag: :force_utf8) do
            VCR.use_cassette('vaos/ccra/post_get_referral_ref_123', match_requests_on: %i[method path]) do
              expect_metric_increment(described_class::APPT_DRAFT_CREATION_FAILURE_METRIC) do
                post '/vaos/v2/appointments/draft', params: draft_params, headers: inflection_header
              end

              response_obj = JSON.parse(response.body)
              expect(response).to have_http_status(:unprocessable_entity)
              error = response_obj['errors'].first
              expect(error['title']).to eq('Appointment creation failed')
              expect(error['detail']).to eq('No new appointment created: referral is already used')
            end
          end
        end

        it 'fails if an eps appointment with the given referral id already exists' do
          draft_params[:referral_number] = 'ref-125'
          VCR.use_cassette('vaos/ccra/post_get_referral_ref_123', match_requests_on: %i[method path]) do
            VCR.use_cassette('vaos/v2/appointments/get_appointments_200', match_requests_on: %i[method path]) do
              VCR.use_cassette('vaos/eps/token/token_200', match_requests_on: %i[method path]) do
                VCR.use_cassette('vaos/eps/get_appointments/200_with_referral_number_no_appointments',
                                 match_requests_on: %i[method path]) do
                  expect_metric_increment(described_class::APPT_DRAFT_CREATION_FAILURE_METRIC) do
                    post '/vaos/v2/appointments/draft', params: draft_params, headers: inflection_header
                  end
                end
              end
            end
          end

          response_obj = JSON.parse(response.body)
          expect(response).to have_http_status(:unprocessable_entity)
          expect(response_obj['errors'].first['title']).to eq('Appointment creation failed')
          expect(response_obj['errors'].first['detail']).to eq('No new appointment created: referral is already used')
        end
      end

      context 'when there is a failure in the request for appointments from CCRA' do
        it 'handles error response as 500' do
          # We mock the referral service to return a referral detail object, so it doesn't use a security token.
          allow_any_instance_of(Ccra::ReferralService).to receive(:get_referral)
            .and_return(
              instance_double(Ccra::ReferralDetail,
                              referral_number: 'ref-126',
                              category_of_care: 'UROLOGY',
                              expiration_date: end_date,
                              provider_npi: npi,
                              referral_date: start_date,
                              treating_facility: 'VA Medical Center',
                              station_id: '528A6',
                              provider_name: 'Dr. Test Provider',
                              provider_specialty: 'UROLOGY',
                              treating_facility_name: 'Test Treating Facility',
                              treating_facility_code: '528A7',
                              treating_facility_phone: '555-123-4567',
                              treating_facility_address: address,
                              referring_facility_name: 'Test Referring Facility',
                              referring_facility_phone: '555-123-0000',
                              referring_facility_code: '528A6',
                              referring_facility_address: {
                                street1: '123 Test Street',
                                city: 'Test City',
                                state: 'FL',
                                zip: '12345'
                              },
                              appointments: { system: 'EPS', data: [] },
                              selected_npi_for_eps: npi,
                              selected_npi_source: :treating_nested)
            )

          expected_error = MAP::SecurityToken::Errors::MissingICNError.new 'Missing ICN message'
          allow_any_instance_of(VAOS::SessionService).to receive(:headers).and_raise(expected_error)

          expect_metric_increment(described_class::APPT_DRAFT_CREATION_FAILURE_METRIC) do
            post '/vaos/v2/appointments/draft', params: draft_params, headers: inflection_header
          end

          response_obj = JSON.parse(response.body)
          expect(response).to have_http_status(:bad_gateway)
          expect(response_obj['errors'].first['title']).to eq('Appointment creation failed')
          expect(response_obj['errors'].first['detail']).to eq(
            'Error checking existing appointments: Missing ICN message'
          )
        end

        it 'handles partial error as 500' do
          expected_error_msg = 'Error checking existing appointments: ' \
                               '[{:system=>"VSP", :status=>"500", :code=>10000, ' \
                               ':message=>"Could not fetch appointments from Vista Scheduling Provider", ' \
                               ':detail=>"icn=1012846043V576341, startDate=1921-09-02T00:00:00Z, ' \
                               'endDate=2121-09-02T00:00:00Z"}]'
          VCR.use_cassette('vaos/v2/appointments/get_appointments_200_with_partial_errors',
                           match_requests_on: %i[method path query]) do
            VCR.use_cassette('vaos/ccra/post_get_referral_ref_123', match_requests_on: %i[method path]) do
              expect_metric_increment(described_class::APPT_DRAFT_CREATION_FAILURE_METRIC) do
                post '/vaos/v2/appointments/draft', params: draft_params, headers: inflection_header
              end

              response_obj = JSON.parse(response.body)
              expect(response).to have_http_status(:bad_gateway)
              expect(response_obj['errors'].first['title']).to eq('Appointment creation failed')
              expect(response_obj['errors'].first['detail']).to eq(expected_error_msg)
            end
          end
        end
      end

      context 'when fetching appointments from EPS returns a 500 error' do
        it 'returns a bad_gateway status and appropriate error message' do
          VCR.use_cassette('vaos/ccra/post_get_referral_ref_123', match_requests_on: %i[method path]) do
            VCR.use_cassette('vaos/eps/get_appointments/500_error', match_requests_on: %i[method path]) do
              VCR.use_cassette('vaos/v2/appointments/get_appointments_200', match_requests_on: %i[method path]) do
                VCR.use_cassette('vaos/eps/get_drive_times/200', match_requests_on: %i[method path]) do
                  VCR.use_cassette 'vaos/eps/get_provider_slots/200', match_requests_on: %i[method path] do
                    VCR.use_cassette 'vaos/eps/get_provider_service/200', match_requests_on: %i[method path] do
                      VCR.use_cassette 'vaos/eps/draft_appointment/200', match_requests_on: %i[method path] do
                        VCR.use_cassette 'vaos/eps/token/token_200', match_requests_on: %i[method path] do
                          expect_metric_increment(described_class::APPT_DRAFT_CREATION_FAILURE_METRIC) do
                            post '/vaos/v2/appointments/draft', params: draft_params, headers: inflection_header
                          end

                          expect(response).to have_http_status(:bad_gateway)
                          response_body = JSON.parse(response.body)
                          expect(response_body).to have_key('errors')
                          expect(response_body['errors']).to be_an(Array)

                          error = response_body['errors'].first
                          expect(error).to include(
                            'title' => 'Appointment creation failed',
                            'detail' => 'Could not create appointment'
                          )

                          expect(error['meta']).to include(
                            'code' => 500,
                            'backendResponse' => '{"isFault": true,"isTemporary": true,"name": "Internal Server Error"}'
                          )

                          expect(error['meta']['originalError']).to include('BackendServiceException')
                          expect(error['meta']['originalError']).to include('vamf_url')
                          expect(error['meta']['originalError']).to include('VAOS_502')
                        end
                      end
                    end
                  end
                end
              end
            end
          end
        end
      end

      context 'when Redis connection fails' do
        it 'returns a bad_gateway status and appropriate error message' do
          # Mock the RedisClient to raise a Redis connection error
          allow_any_instance_of(Ccra::ReferralService).to receive(:get_referral)
            .and_raise(Redis::BaseError, 'Redis connection refused')

          expect_metric_increment(described_class::APPT_DRAFT_CREATION_FAILURE_METRIC) do
            post '/vaos/v2/appointments/draft', params: draft_params, headers: inflection_header
          end

          expect(response).to have_http_status(:bad_gateway)

          response_obj = JSON.parse(response.body)
          error = response_obj['errors'].first
          expect(error['title']).to eq('Appointment creation failed')
          expect(error['detail']).to eq('Redis connection error')
        end
      end

      context 'when request params are missing' do
        it 'returns a bad_request status and appropriate error message' do
          post '/vaos/v2/appointments/draft', params: { referral_consult_id: '12345' }, headers: inflection_header
          expect(response).to have_http_status(:bad_request)
          expect(response.body).to include('param is missing or the value is empty: referral_number')
        end
      end
    end
  end

  # Helper method to verify a StatsD metric is incremented exactly the expected number of times
  def expect_metric_increment(metric_name)
    metric_calls = 0
    allow(StatsD).to receive(:increment) do |metric, *_args|
      metric_calls += 1 if metric == metric_name
    end

    yield

    expect(metric_calls).to eq(1)
  end

  # Helper method to verify a StatsD measure metric is called with the expected value
  def expect_metric_measure(metric_name, expected_value)
    metric_called = false
    allow(StatsD).to receive(:measure) do |metric, value, *_args|
      if metric == metric_name
        metric_called = true
        expect(value).to eq(expected_value)
      end
    end

    yield

    expect(metric_called).to be true
  end
end
