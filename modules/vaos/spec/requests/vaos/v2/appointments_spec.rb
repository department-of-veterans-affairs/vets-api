# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'VAOS::V2::Appointments', :skip_mvi, type: :request do
  include SchemaMatchers

  before do
    allow(Settings.mhv).to receive(:facility_range).and_return([[1, 999]])
    Flipper.enable('va_online_scheduling')
    Flipper.enable(:va_online_scheduling_use_vpg)
    Flipper.enable(:va_online_scheduling_enable_OH_requests)
    Flipper.disable(:va_online_scheduling_vaos_alternate_route)
    Flipper.enable_actor('appointments_consolidation', current_user)
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

    context 'using VPG' do
      describe 'CREATE cc appointment' do
        let(:community_cares_request_body) do
          FactoryBot.build(:appointment_form_v2, :community_cares, user: current_user).attributes
        end

        let(:community_cares_request_body2) do
          FactoryBot.build(:appointment_form_v2, :community_cares2, user: current_user).attributes
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
          FactoryBot.build(:appointment_form_v2, :va_booked, user: current_user).attributes
        end

        let(:va_proposed_request_body) do
          FactoryBot.build(:appointment_form_v2, :va_proposed_clinic, user: current_user).attributes
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

        it 'creates the va appointment - booked' do
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
      end
    end
  end
end
