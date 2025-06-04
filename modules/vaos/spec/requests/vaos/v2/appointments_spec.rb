# frozen_string_literal: true

require 'rails_helper'

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
        allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_OH_request).and_return(false)
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
        allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_OH_request).and_return(true)
        allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_use_vpg, instance_of(User)).and_return(true)
        allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_use_vpg).and_return(true)
        allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_OH_request, instance_of(User)).and_return(true)
        allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_OH_direct_schedule,
                                                  instance_of(User)).and_return(true)
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
          allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_OH_direct_schedule,
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
        let(:avs_error_message) { 'Error retrieving AVS link' }
        let(:avs_path) do
          '/my-health/medical-records/summaries-and-notes/visit-summary/C46E12AA7582F5714716988663350853'
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
          allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_use_vpg, instance_of(User)).and_return(false)
          allow(Flipper).to receive(:enabled?).with('schema_contract_appointments_index').and_return(false)
          allow(Flipper).to receive(:enabled?).with(:travel_pay_view_claim_details, instance_of(User)).and_return(false)
          allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_use_vpg).and_return(false)
        end

        let(:avs_path) do
          '/my-health/medical-records/summaries-and-notes/visit-summary/C46E12AA7582F5714716988663350853'
        end

        it 'has access and returns appointment - va proposed' do
          VCR.use_cassette('vaos/v2/appointments/get_appointment_200_with_facility_200',
                           match_requests_on: %i[method path query]) do
            allow(Rails.logger).to receive(:info).at_least(:once)
            allow_any_instance_of(VAOS::V2::AppointmentsService).to receive(:get_avs_link)
              .and_return(avs_path)
            get '/vaos/v2/appointments/70060', headers: inflection_header
            expect(response).to have_http_status(:ok)
            expect(json_body_for(response)).to match_camelized_schema('vaos/v2/appointment', { strict: false })
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

        context 'with judy morrison test appointment' do
          let(:current_user) { build(:user, :vaos) }
          let(:avs_error_message) { 'Error retrieving AVS link' }

          it 'includes an avs error message in response when appointment has no available avs' do
            stub_clinics
            VCR.use_cassette('vaos/v2/appointments/get_appointment_200_no_avs',
                             match_requests_on: %i[method path query]) do
              allow(Rails.logger).to receive(:info).at_least(:once)
              get '/vaos/v2/appointments/192308', headers: inflection_header
              expect(response).to have_http_status(:ok)
              expect(json_body_for(response)).to match_camelized_schema('vaos/v2/appointment', { strict: false })
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
            expect(json_body_for(response)).to match_camelized_schema('vaos/v2/appointment', { strict: false })
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
            expect(json_body_for(response)).to match_camelized_schema('vaos/v2/appointment', { strict: false })
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
          VCR.use_cassette('vaos/v2/appointments/get_appointment_200',
                           match_requests_on: %i[method path query]) do
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
          allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_use_vpg, instance_of(User)).and_return(false)
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
          allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_use_vpg, instance_of(User)).and_return(false)
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
          allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_enable_OH_cancellations,
                                                    instance_of(User)).and_return(false)
          allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_use_vpg).and_return(false)
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
          allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_enable_OH_cancellations).and_return(false)
          VCR.use_cassette('vaos/v2/appointments/cancel_appointment_400', match_requests_on: %i[method path query]) do
            put '/vaos/v2/appointments/42081', params: { status: 'cancelled' }
            expect(response).to have_http_status(:bad_request)
            expect(JSON.parse(response.body)['errors'][0]['code']).to eq('VAOS_400')
          end
        end
      end

      context 'when the backend service cannot handle the request' do
        before do
          allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_enable_OH_cancellations,
                                                    instance_of(User)).and_return(false)
          allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_use_vpg).and_return(false)
        end

        it 'returns a 502 status code' do
          VCR.use_cassette('vaos/v2/appointments/cancel_appointment_500', match_requests_on: %i[method path query]) do
            put '/vaos/v2/appointments/35952', params: { status: 'cancelled' }
            expect(response).to have_http_status(:bad_gateway)
            expect(JSON.parse(response.body)['errors'][0]['code']).to eq('VAOS_502')
          end
        end
      end
    end

    describe 'POST appointments/submit' do
      before do
        allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_enable_OH_cancellations,
                                                  instance_of(User)).and_return(false)
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

        it 'successfully submits referral appointment' do
          VCR.use_cassette('vaos/v2/eps/post_access_token',
                           match_requests_on: %i[method path]) do
            VCR.use_cassette('vaos/v2/eps/post_submit_appointment',
                             match_requests_on: %i[method path body]) do
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
              post '/vaos/v2/appointments/submit', params:, headers: inflection_header

              response_obj = JSON.parse(response.body)
              expect(response).to have_http_status(:conflict)
              expect(response_obj.dig('errors', 0, 'code')).to eql('conflict')
            end
          end
        end

        it 'records success metric when submitting referral appointment' do
          VCR.use_cassette('vaos/v2/eps/post_access_token',
                           match_requests_on: %i[method path]) do
            VCR.use_cassette('vaos/v2/eps/post_submit_appointment',
                             match_requests_on: %i[method path body]) do
              # Allow any StatsD calls and check for our specific metric
              allow(StatsD).to receive(:increment).with(any_args)
              expect(StatsD).to receive(:increment)
                .with(described_class::APPT_CREATION_SUCCESS_METRIC)

              post '/vaos/v2/appointments/submit', params:, headers: inflection_header

              expect(response).to have_http_status(:created)
            end
          end
        end

        it 'handles EPS error response' do
          VCR.use_cassette('vaos/v2/eps/post_access_token',
                           match_requests_on: %i[method path]) do
            VCR.use_cassette('vaos/v2/eps/post_submit_appointment_400',
                             match_requests_on: %i[method path]) do
              post '/vaos/v2/appointments/submit', params: { ** params, phone_number: nil }, headers: inflection_header

              response_obj = JSON.parse(response.body)
              expect(response).to have_http_status(:bad_request)
              expect(response_obj['errors'].length).to be(1)
              expect(response_obj['errors'][0]['detail']).to eql('missing patient attributes: phone')
            end
          end
        end

        it 'records failure metric when appointment submission fails' do
          VCR.use_cassette('vaos/v2/eps/post_access_token',
                           match_requests_on: %i[method path]) do
            # Mock a failed appointment submission (nil id)
            allow_any_instance_of(Eps::AppointmentService).to receive(:submit_appointment)
              .and_return(OpenStruct.new(id: nil))

            # Allow any StatsD calls and check for our specific metric
            allow(StatsD).to receive(:increment).with(any_args)
            expect(StatsD).to receive(:increment)
              .with(described_class::APPT_CREATION_FAILURE_METRIC)

            post '/vaos/v2/appointments/submit', params:, headers: inflection_header

            expect(response).to have_http_status(:unprocessable_entity)
            response_obj = JSON.parse(response.body)
            expect(response_obj['errors']).to be_an(Array)
            expect(response_obj['errors'][0]['title']).to eq('Appointment creation failed')
          end
        end
      end
    end
  end

  context 'for eps referrals' do
    let(:current_user) { build(:user, :vaos, icn: 'care-nav-patient-casey') }
    let(:memory_store) { ActiveSupport::Cache.lookup_store(:memory_store) }
    let(:redis_token_expiry) { 59.minutes }
    let(:npi) { '7894563210' }
    let(:appointment_type_id) { 'ov' }
    let(:start_date) { '2025-01-01T00:00:00Z' }
    let(:end_date) { '2025-01-03T00:00:00Z' }
    let(:referral_data) do
      {
        referral_number: 'ref-123',
        referral_consult_id: '123-123456',
        npi:,
        appointment_type_id:,
        start_date:,
        end_date:
      }
    end

    let(:draft_params) do
      {
        referral_number: referral_data[:referral_number],
        referral_consult_id: referral_data[:referral_consult_id]
      }
    end

    let(:referral_detail) do
      instance_double(Ccra::ReferralDetail,
                      referral_number: 'ref-123',
                      appointment_type_id:,
                      expiration_date: end_date,
                      provider_npi: npi,
                      referral_date: start_date)
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
      allow(Flipper).to receive(:enabled?).with(:remove_pciu, instance_of(User)).and_return(false)
      allow(Flipper).to receive(:enabled?).with('schema_contract_appointments_index').and_return(true)
      Timecop.freeze(DateTime.parse('2021-09-02T14:00:00Z'))

      allow(Rails).to receive(:cache).and_return(memory_store)
      Rails.cache.clear
      # Set up mocks for CCRA service to return the referral detail
      allow_any_instance_of(Ccra::ReferralService).to receive(:get_referral)
        .with(referral_data[:referral_consult_id], current_user.icn)
        .and_return(referral_detail)
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
            'id' => '53mL4LAZ',
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

        it 'returns a successful response when all calls succeed' do
          VCR.use_cassette('vaos/v2/appointments/get_appointments_200', match_requests_on: %i[method path]) do
            VCR.use_cassette('vaos/eps/get_drive_times/200', match_requests_on: %i[method path]) do
              VCR.use_cassette 'vaos/eps/get_provider_slots/200', match_requests_on: %i[method path] do
                VCR.use_cassette('vaos/eps/search_provider_services/200', match_requests_on: %i[method path]) do
                  VCR.use_cassette 'vaos/eps/draft_appointment/200', match_requests_on: %i[method path] do
                    VCR.use_cassette 'vaos/eps/token/token_200', match_requests_on: %i[method path] do
                      allow_any_instance_of(Eps::AppointmentService)
                        .to receive(:get_appointments)
                        .and_return(OpenStruct.new(data: []))

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

        it 'records success metric when draft appointment is created successfully' do
          VCR.use_cassette('vaos/v2/appointments/get_appointments_200', match_requests_on: %i[method path]) do
            VCR.use_cassette('vaos/eps/get_drive_times/200', match_requests_on: %i[method path]) do
              VCR.use_cassette 'vaos/eps/get_provider_slots/200', match_requests_on: %i[method path] do
                VCR.use_cassette('vaos/eps/search_provider_services/200', match_requests_on: %i[method path]) do
                  VCR.use_cassette 'vaos/eps/draft_appointment/200', match_requests_on: %i[method path] do
                    VCR.use_cassette 'vaos/eps/token/token_200', match_requests_on: %i[method path] do
                      allow_any_instance_of(Eps::AppointmentService)
                        .to receive(:get_appointments)
                        .and_return(OpenStruct.new(data: []))

                      # Allow any StatsD calls and check for our specific metric
                      allow(StatsD).to receive(:increment).with(any_args)
                      expect(StatsD).to receive(:increment)
                        .with(described_class::APPT_CREATION_SUCCESS_METRIC)

                      post '/vaos/v2/appointments/draft', params: draft_params, headers: inflection_header

                      expect(response).to have_http_status(:created)
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
          VCR.use_cassette('vaos/v2/appointments/get_appointments_200', match_requests_on: %i[method path]) do
            VCR.use_cassette('vaos/eps/get_drive_times/200', match_requests_on: %i[method path]) do
              VCR.use_cassette 'vaos/eps/get_provider_slots/200', match_requests_on: %i[method path] do
                VCR.use_cassette('vaos/eps/search_provider_services/200', match_requests_on: %i[method path]) do
                  # Create a nil draft response to trigger the failure case
                  allow_any_instance_of(Eps::AppointmentService).to receive(:create_draft_appointment)
                    .and_return(nil)

                  allow_any_instance_of(Eps::AppointmentService).to receive(:get_appointments)
                    .and_return(OpenStruct.new(data: []))

                  post '/vaos/v2/appointments/draft', params: draft_params, headers: inflection_header

                  expect(response).to have_http_status(:internal_server_error)
                  response_obj = JSON.parse(response.body)
                  expect(response_obj['errors']).to be_an(Array)
                  expect(response_obj['errors'][0]['title']).to eq('Internal server error')
                end
              end
            end
          end
        end
      end

      context 'when drive time coords are invalid' do
        it 'handles invalid_range response' do
          VCR.use_cassette('vaos/v2/appointments/get_appointments_200', match_requests_on: %i[method path]) do
            VCR.use_cassette 'vaos/eps/get_drive_times/400_invalid_coords', match_requests_on: %i[method path] do
              VCR.use_cassette 'vaos/eps/get_provider_slots/200', match_requests_on: %i[method path] do
                VCR.use_cassette 'vaos/eps/search_provider_services/200', match_requests_on: %i[method path] do
                  VCR.use_cassette 'vaos/eps/draft_appointment/200', match_requests_on: %i[method path] do
                    VCR.use_cassette 'vaos/eps/token/token_200', match_requests_on: %i[method path] do
                      allow_any_instance_of(Eps::AppointmentService)
                        .to receive(:get_appointments)
                        .and_return(OpenStruct.new(data: []))
                      post '/vaos/v2/appointments/draft', params: draft_params

                      expect(response).to have_http_status(:bad_request)
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
          VCR.use_cassette('vaos/v2/appointments/get_appointments_200', match_requests_on: %i[method path]) do
            VCR.use_cassette 'vaos/eps/search_provider_services/empty_200', match_requests_on: %i[method path] do
              VCR.use_cassette 'vaos/eps/token/token_200', match_requests_on: %i[method path] do
                allow_any_instance_of(Eps::AppointmentService)
                  .to receive(:get_appointments)
                  .and_return(OpenStruct.new(data: []))
                post '/vaos/v2/appointments/draft', params: draft_params

                expect(response).to have_http_status(:not_found)
              end
            end
          end
        end
      end

      context 'when patient id is invalid' do
        it 'handles invalid patientId response as 400' do
          VCR.use_cassette('vaos/v2/appointments/get_appointments_200', match_requests_on: %i[method path]) do
            VCR.use_cassette 'vaos/eps/get_provider_slots/200', match_requests_on: %i[method path] do
              VCR.use_cassette('vaos/eps/search_provider_services/200', match_requests_on: %i[method path]) do
                VCR.use_cassette 'vaos/eps/draft_appointment/400_invalid_patientid',
                                 match_requests_on: %i[method path] do
                  VCR.use_cassette 'vaos/eps/token/token_200', match_requests_on: %i[method path] do
                    allow_any_instance_of(Eps::AppointmentService)
                      .to receive(:get_appointments)
                      .and_return(OpenStruct.new(data: []))
                    post '/vaos/v2/appointments/draft', params: draft_params

                    expect(response).to have_http_status(:bad_request)
                  end
                end
              end
            end
          end
        end
      end

      context 'when there is already an appointment associated with the referral' do
        it 'fails if a vaos appointment with the given referral id already exists' do
          VCR.use_cassette('vaos/v2/appointments/get_appointments_200',
                           match_requests_on: %i[method path query], allow_playback_repeats: true, tag: :force_utf8) do
            referral_data = {
              referral_number: 'ref-124',
              npi:,
              appointment_type_id:,
              start_date:,
              end_date:
            }

            # Set up the test referral for this test case
            specific_referral_detail = instance_double(Ccra::ReferralDetail,
                                                       referral_number: referral_data[:referral_number],
                                                       appointment_type_id: referral_data[:appointment_type_id],
                                                       expiration_date: referral_data[:end_date],
                                                       provider_npi: referral_data[:npi],
                                                       referral_date: referral_data[:start_date])

            allow_any_instance_of(Ccra::ReferralService).to receive(:get_referral)
              .with(referral_data[:referral_consult_id], current_user.icn)
              .and_return(specific_referral_detail)

            draft_params[:referral_number] = 'ref-124'
            post '/vaos/v2/appointments/draft', params: draft_params, headers: inflection_header

            response_obj = JSON.parse(response.body)
            expect(response).to have_http_status(:unprocessable_entity)
            expect(response_obj['message']).to eq('No new appointment created: referral is already used')
          end
        end

        it 'fails if an eps appointment with the given referral id already exists' do
          eps_appointments = OpenStruct.new(data:
            [
              {
                id: '124',
                state: 'proposed',
                patient_id: '457',
                referral: {
                  referral_number: 'ref-126'
                },
                provider_service_id: 'DBKQ-H0a',
                network_id: 'random-sandbox-network-id',
                slot_ids: [
                  '5vuTac8v-practitioner-8-role-1|' \
                  '9783e46c-efe2-462c-84a1-7af5f5f6613a|' \
                  '2024-12-01T10:00:00Z|30m0s|1733338893365|ov'
                ],
                appointment_details: {
                  status: 'booked',
                  start: '2024-12-02T10:00:00Z',
                  is_latest: false,
                  last_retrieved: '2024-12-02T10:00:00Z'
                }
              }
            ])

          vaos_appointments = OpenStruct.new(data: [], meta: {})
          allow_any_instance_of(VAOS::V2::AppointmentsService).to receive(:get_all_appointments).and_return(
            vaos_appointments
          )
          allow_any_instance_of(Eps::AppointmentService).to receive(:get_appointments).and_return(eps_appointments)

          referral_data = {
            referral_number: 'ref-126',
            npi:,
            appointment_type_id:,
            start_date:,
            end_date:
          }

          # Set up the test referral for this test case
          ref126_detail = instance_double(Ccra::ReferralDetail,
                                          referral_number: referral_data[:referral_number],
                                          appointment_type_id: referral_data[:appointment_type_id],
                                          expiration_date: referral_data[:end_date],
                                          provider_npi: referral_data[:npi],
                                          referral_date: referral_data[:start_date])

          allow_any_instance_of(Ccra::ReferralService).to receive(:get_referral)
            .with(referral_data[:referral_consult_id], current_user.icn)
            .and_return(ref126_detail)

          draft_params[:referral_number] = 'ref-126'
          post '/vaos/v2/appointments/draft', params: draft_params, headers: inflection_header

          response_obj = JSON.parse(response.body)
          expect(response).to have_http_status(:unprocessable_entity)
          expect(response_obj['message']).to eq('No new appointment created: referral is already used')
        end
      end

      context 'when there is a failure in the request for appointments from CCRA' do
        it 'handles error response as 500' do
          expected_error = MAP::SecurityToken::Errors::MissingICNError.new 'Missing ICN message'
          allow_any_instance_of(VAOS::SessionService).to receive(:headers).and_raise(expected_error)
          post '/vaos/v2/appointments/draft', params: draft_params, headers: inflection_header

          response_obj = JSON.parse(response.body)
          expect(response).to have_http_status(:bad_gateway)
          expect(response_obj['message']).to eq('Error checking appointments: Missing ICN message')
        end

        it 'handles partial error as 500' do
          expected_error_msg = 'Error checking appointments: ' \
                               '[{:system=>"VSP", :status=>"500", :code=>10000, ' \
                               ':message=>"Could not fetch appointments from Vista Scheduling Provider", ' \
                               ':detail=>"icn=1012846043V576341, startDate=1921-09-02T00:00:00Z, ' \
                               'endDate=2121-09-02T00:00:00Z"}]'
          VCR.use_cassette('vaos/v2/appointments/get_appointments_200_with_partial_errors',
                           match_requests_on: %i[method path query]) do
            post '/vaos/v2/appointments/draft', params: draft_params, headers: inflection_header

            response_obj = JSON.parse(response.body)
            expect(response).to have_http_status(:bad_gateway)
            expect(response_obj['message']).to eq(expected_error_msg)
          end
        end
      end

      context 'when the upstream service returns a 500 error' do
        it 'returns a bad_gateway status and appropriate error message' do
          VCR.use_cassette('vaos/eps/get_appointments/500_error', match_requests_on: %i[method path]) do
            VCR.use_cassette('vaos/v2/appointments/get_appointments_200', match_requests_on: %i[method path]) do
              VCR.use_cassette('vaos/eps/get_drive_times/200', match_requests_on: %i[method path]) do
                VCR.use_cassette 'vaos/eps/get_provider_slots/200', match_requests_on: %i[method path] do
                  VCR.use_cassette 'vaos/eps/get_provider_service/200', match_requests_on: %i[method path] do
                    VCR.use_cassette 'vaos/eps/draft_appointment/200', match_requests_on: %i[method path] do
                      VCR.use_cassette 'vaos/eps/token/token_200', match_requests_on: %i[method path] do
                        post '/vaos/v2/appointments/draft', params: draft_params, headers: inflection_header

                        expect(response).to have_http_status(:bad_gateway)
                        response_body = JSON.parse(response.body)
                        expect(response_body).to have_key('errors')
                        expect(response_body['errors']).to be_an(Array)

                        error = response_body['errors'].first
                        expect(error).to include(
                          'title' => 'Bad Gateway',
                          'detail' => 'Received an an invalid response from the upstream server',
                          'code' => 'VAOS_502',
                          'status' => '502',
                          'source' => {
                            'vamfUrl' => 'https://api.wellhive.com/care-navigation/v1/appointments?patientId=care-nav-patient-casey',
                            'vamfBody' => '{"isFault": true,"isTemporary": true,"name": "Internal Server Error"}',
                            'vamfStatus' => 500
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

      context 'when Redis connection fails' do
        it 'returns a bad_gateway status and appropriate error message' do
          # Mock the RedisClient to raise a Redis connection error
          allow_any_instance_of(Ccra::ReferralService).to receive(:get_referral)
            .and_raise(Redis::BaseError, 'Redis connection refused')

          post '/vaos/v2/appointments/draft', params: draft_params, headers: inflection_header

          expect(response).to have_http_status(:bad_gateway)

          response_obj = JSON.parse(response.body)
          expect(response_obj['errors'].first['title']).to eq('Error fetching referral data from cache')
          expect(response_obj['errors'].first['detail']).to eq('Unable to connect to cache service')
        end
      end
    end
  end
end
