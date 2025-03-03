# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'VAOS::V2::Appointments', :skip_mvi, type: :request do
  include SchemaMatchers

  before do
    allow(Settings.mhv).to receive(:facility_range).and_return([[1, 999]])
    allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_vaos_alternate_route).and_return(false)
    allow(Flipper).to receive(:enabled?).with(:appointments_consolidation, instance_of(User)).and_return(true)
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
        allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_sts_oauth_token,
                                                  instance_of(User)).and_return(true)
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
        allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_sts_oauth_token,
                                                  instance_of(User)).and_return(true)
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
            allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_sts_oauth_token,
                                                      instance_of(User)).and_return(true)
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
            allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_sts_oauth_token,
                                                      instance_of(User)).and_return(true)
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
              expect(data[0]['attributes']['friendlyName']).to eq('service_name')
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
              expect(data.size).to eq(10)
              expect(data[0]['attributes']['location']).to eq(facility_error_msg)
              expect(data[9]['attributes']['location']).not_to eq(facility_error_msg)
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
              expect(data[0]['attributes']['location']).to eq(facility_error_msg)
              expect(data[9]['attributes']['location']).not_to eq(facility_error_msg)
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
          allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_sts_oauth_token,
                                                    instance_of(User)).and_return(true)
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

        it 'updates the service name, physical location, friendly name, and location' do
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
            expect(data['friendlyName']).to eq('Service Name')
            expect(data['location']).to eq(expected_facility)
            expect(Rails.logger).to have_received(:info).with(
              'VAOS::V2::AppointmentsController appointment creation time: 2021-12-13T14:03:02Z',
              { created: '2021-12-13T14:03:02Z' }.to_json
            )
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
    end

    describe 'PUT appointments' do
      context 'when the appointment is successfully cancelled' do
        before do
          allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_enable_OH_cancellations,
                                                    instance_of(User)).and_return(false)
          allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_sts_oauth_token,
                                                    instance_of(User)).and_return(true)
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
          it 'updates the service name, physical location, friendly name, and location' do
            allow_any_instance_of(VAOS::V2::MobileFacilityService).to receive(:get_clinic)
              .and_return(service_name: 'Service Name', physical_location: 'Physical Location')
            stub_facilities
            VCR.use_cassette('vaos/v2/appointments/cancel_appointments_200',
                             match_requests_on: %i[method path query]) do
              put '/vaos/v2/appointments/70060', params: { status: 'cancelled' }, headers: inflection_header

              data = json_body_for(response)['attributes']
              expect(data['serviceName']).to eq('Service Name')
              expect(data['physicalLocation']).to eq('Physical Location')
              expect(data['friendlyName']).to eq('Service Name')
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
          allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_sts_oauth_token,
                                                    instance_of(User)).and_return(true)
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
        allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_sts_oauth_token,
                                                  instance_of(User)).and_return(true)
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
      end
    end
  end

  context 'for eps referrals' do
    let(:current_user) { build(:user, :vaos, icn: 'care-nav-patient-casey') }

    before do
      allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_sts_oauth_token,
                                                instance_of(User)).and_return(true)
      allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_use_vpg).and_return(false)
    end

    describe 'POST create_draft' do
      context 'when the request is successful' do
        let(:draft_params) do
          {
            referral_id: 'ref-123',
            provider_id: '9mN718pH',
            appointment_type_id: 'ov',
            start_date: '2025-01-01T00:00:00Z',
            end_date: '2025-01-03T00:00:00Z'
          }
        end

        let(:draft_appointment_response) do
          {
            id: 'EEKoGzEf',
            state: 'draft',
            patientId: 'ref-123'
          }
        end

        let(:provider_response) do
          {
            'id' => '9mN718pH',
            'name' => 'Dr. Moreen S. Rafa @ FHA South Melbourne Medical Complex',
            'isActive' => true,
            'individualProviders' => [
              {
                'name' => 'Dr. Moreen S. Rafa',
                'npi' => '91560381x'
              }
            ],
            'providerOrganization' => {
              'name' => 'Meridian Health (Sandbox 5vuTac8v)'
            },
            'location' => {
              'name' => 'FHA South Melbourne Medical Complex',
              'address' => '1105 Palmetto Ave, Melbourne, FL, 32901, US',
              'latitude' => 28.08061,
              'longitude' => -80.60322,
              'timezone' => 'America/New_York'
            },
            'networkIds' => ['sandbox-network-5vuTac8v'],
            'schedulingNotes' => 'New patients need to send their previous records to the office prior to their appt.',
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
            'visitMode' => 'phone',
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
                'provider' => provider_response,
                'slots' => slots_response['slots'],
                'drivetime' => drive_times_response
              }
            }
          }
        end

        it 'returns a successful response when all calls succeed' do
          VCR.use_cassette('vaos/eps/get_drive_times/200', match_requests_on: %i[method path body]) do
            VCR.use_cassette 'vaos/eps/get_provider_slots/200' do
              VCR.use_cassette 'vaos/eps/get_provider_service/200' do
                VCR.use_cassette 'vaos/eps/draft_appointment/200' do
                  VCR.use_cassette 'vaos/eps/token/token_200' do
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

      context 'when user address does not have coordinates' do
        before do
          allow_any_instance_of(User).to receive(:vet360_contact_info).and_return(nil)
        end

        let(:draft_params) do
          {
            referral_id: 'ref-123',
            provider_id: '9mN718pH',
            appointment_type_id: 'ov',
            start_date: '2025-01-01T00:00:00Z',
            end_date: '2025-01-03T00:00:00Z'
          }
        end

        let(:draft_appointment_response) do
          {
            id: 'EEKoGzEf',
            state: 'draft',
            patientId: 'ref-123'
          }
        end

        let(:provider_response) do
          {
            'id' => '9mN718pH',
            'name' => 'Dr. Moreen S. Rafa @ FHA South Melbourne Medical Complex',
            'isActive' => true,
            'individualProviders' => [
              {
                'name' => 'Dr. Moreen S. Rafa',
                'npi' => '91560381x'
              }
            ],
            'providerOrganization' => {
              'name' => 'Meridian Health (Sandbox 5vuTac8v)'
            },
            'location' => {
              'name' => 'FHA South Melbourne Medical Complex',
              'address' => '1105 Palmetto Ave, Melbourne, FL, 32901, US',
              'latitude' => 28.08061,
              'longitude' => -80.60322,
              'timezone' => 'America/New_York'
            },
            'networkIds' => ['sandbox-network-5vuTac8v'],
            'schedulingNotes' => 'New patients need to send their previous records to the office prior to their appt.',
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
            'visitMode' => 'phone',
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

        let(:expected_response) do
          {
            'data' => {
              'id' => draft_appointment_response[:id],
              'type' => 'draft_appointment',
              'attributes' => {
                'provider' => provider_response,
                'slots' => slots_response['slots'],
                'drivetime' => nil
              }
            }
          }
        end

        it 'returns a successful response when all calls succeed' do
          VCR.use_cassette 'vaos/eps/get_provider_slots/200' do
            VCR.use_cassette 'vaos/eps/get_provider_service/200' do
              VCR.use_cassette 'vaos/eps/draft_appointment/200' do
                VCR.use_cassette 'vaos/eps/token/token_200' do
                  post '/vaos/v2/appointments/draft', params: draft_params, headers: inflection_header

                  expect(response).to have_http_status(:created)
                  expect(JSON.parse(response.body)).to eq(expected_response)
                end
              end
            end
          end
        end
      end

      context 'when drive time coords are invalid' do
        let(:draft_params) do
          {
            referral_id: 'ref-123',
            provider_id: '9mN718pH',
            appointment_type_id: 'ov',
            start_date: '2025-01-01T00:00:00Z',
            end_date: '2025-01-03T00:00:00Z'
          }
        end

        it 'handles invalid_range response' do
          VCR.use_cassette 'vaos/eps/get_drive_times/400_invalid_coords' do
            VCR.use_cassette 'vaos/eps/get_provider_slots/200' do
              VCR.use_cassette 'vaos/eps/get_provider_service/200' do
                VCR.use_cassette 'vaos/eps/draft_appointment/200' do
                  VCR.use_cassette 'vaos/eps/token/token_200' do
                    post '/vaos/v2/appointments/draft', params: draft_params

                    expect(response).to have_http_status(:bad_request)
                  end
                end
              end
            end
          end
        end
      end

      context 'when provider ID is invalid' do
        let(:draft_params) do
          {
            referral_id: 'ref-123',
            provider_id: '9mN718pHa',
            appointment_type_id: 'ov',
            start_date: '2025-01-01T00:00:00Z',
            end_date: '2025-01-03T00:00:00Z'
          }
        end

        it 'handles provider-services 404 response' do
          VCR.use_cassette 'vaos/eps/get_provider_service/404_unknown_provider' do
            VCR.use_cassette 'vaos/eps/draft_appointment/200' do
              VCR.use_cassette 'vaos/eps/token/token_200' do
                post '/vaos/v2/appointments/draft', params: draft_params

                expect(response).to have_http_status(:not_found)
              end
            end
          end
        end
      end

      context 'when patient id is invalid' do
        let(:draft_params) do
          {
            referral_id: 'ref-123',
            provider_id: '9mN718pH',
            appointment_type_id: 'ov',
            start_date: '2025-01-01T00:00:00Z',
            end_date: '2025-01-03T00:00:00Z'
          }
        end

        it 'handles invalid patientId response as 400' do
          VCR.use_cassette 'vaos/eps/draft_appointment/400_invalid_patientid' do
            VCR.use_cassette 'vaos/eps/token/token_200' do
              post '/vaos/v2/appointments/draft', params: draft_params

              expect(response).to have_http_status(:bad_request)
            end
          end
        end
      end

      context 'when missing provider_id' do
        let(:draft_params) do
          {
            referral_id: 'ref-123',
            appointment_type_id: 'ov',
            start_date: '2025-01-01T00:00:00Z',
            end_date: '2025-01-03T00:00:00Z'
          }
        end

        it 'handles invalid patientId response as 400' do
          post '/vaos/v2/appointments/draft', params: draft_params

          response_obj = JSON.parse(response.body)
          expect(response).to have_http_status(:bad_request)
          expect(response_obj['errors'].length).to be(1)
          expect(response_obj['errors'][0]['detail']).to eql(
            'The required parameter "provider_id", is missing'
          )
        end
      end
    end
  end
end
