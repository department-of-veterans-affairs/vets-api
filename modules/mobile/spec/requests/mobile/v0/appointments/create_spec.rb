# frozen_string_literal: true

require_relative '../../../../support/helpers/rails_helper'

RSpec.describe 'Mobile::V0::Appointments#create', :skip_mvi, type: :request do
  include SchemaMatchers
  mock_clinic = {
    service_name: 'service_name',
    physical_location: 'physical_location'
  }

  mock_facility = {
    'test' => 'test'
  }

  let!(:user) { sis_user(icn: '1012846043V576341') }

  before do
    allow_any_instance_of(User).to receive(:va_patient?).and_return(true)
    allow_any_instance_of(VAOS::UserService).to receive(:session).and_return('stubbed_token')
    allow_any_instance_of(VAOS::V2::MobileFacilityService).to \
      receive(:get_clinic).and_return(mock_clinic)
    allow_any_instance_of(VAOS::V2::MobileFacilityService).to \
      receive(:get_facility).and_return(mock_facility)
    allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_vaos_alternate_route).and_return(false)
  end

  describe 'CREATE appointment', :aggregate_failures do
    let(:community_cares_request_body) do
      build(:appointment_form_v2, :community_cares).attributes
    end
    let(:va_booked_request_body) do
      build(:appointment_form_v2, :va_booked).attributes
    end
    let(:va_proposed_request_body) do
      build(:appointment_form_v2, :va_proposed_clinic).attributes
    end

    describe 'authorization' do
      context 'when user does not have access' do
        let!(:user) { sis_user(:api_auth, :loa1, icn: nil) }

        it 'returns forbidden' do
          post '/mobile/v0/appointment', params: va_proposed_request_body, headers: sis_headers
          expect(response).to have_http_status(:forbidden)
        end
      end

      context 'when user has access' do
        context 'using VAOS' do
          before do
            allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_use_vpg,
                                                      instance_of(User)).and_return(false)
          end

          it 'returns created' do
            VCR.use_cassette('mobile/appointments/post_appointments_va_booked_200_JACQUELINE_M',
                             match_requests_on: %i[method uri]) do
              VCR.use_cassette('mobile/appointments/VAOS_v2/get_facilities_200', match_requests_on: %i[method uri]) do
                post '/mobile/v0/appointment', params: {}, headers: sis_headers
                expect(response).to have_http_status(:created)
              end
            end
          end
        end

        context 'using VPG' do
          before do
            allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_use_vpg, instance_of(User)).and_return(true)
          end

          it 'returns created' do
            VCR.use_cassette('mobile/appointments/post_appointments_va_booked_200_JACQUELINE_M_vpg',
                             match_requests_on: %i[method uri]) do
              VCR.use_cassette('mobile/appointments/VAOS_v2/get_facilities_200', match_requests_on: %i[method uri]) do
                post '/mobile/v0/appointment', params: {}, headers: sis_headers
                expect(response).to have_http_status(:created)
              end
            end
          end
        end
      end
    end

    context 'using VAOS' do
      before do
        allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_use_vpg, instance_of(User)).and_return(false)
      end

      it 'returns a descriptive 400 error when given invalid params' do
        VCR.use_cassette('mobile/appointments/post_appointments_400', match_requests_on: %i[method uri]) do
          post '/mobile/v0/appointment', params: {}, headers: sis_headers
          expect(response).to have_http_status(:bad_request)
          expect(JSON.parse(response.body)['errors'][0]['status']).to eq('400')
          expect(JSON.parse(response.body)['errors'][0]['detail']).to eq(
            'the patientIcn must match the ICN in the request URI'
          )
        end
      end
    end

    context 'using VPG' do
      before do
        allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_use_vpg, instance_of(User)).and_return(true)
      end

      it 'returns a descriptive 400 error when given invalid params' do
        VCR.use_cassette('mobile/appointments/post_appointments_400_vpg', match_requests_on: %i[method uri]) do
          post '/mobile/v0/appointment', params: {}, headers: sis_headers
          expect(response).to have_http_status(:bad_request)
          expect(JSON.parse(response.body)['errors'][0]['status']).to eq('400')
          expect(JSON.parse(response.body)['errors'][0]['detail']).to eq(
            'the patientIcn must match the ICN in the request URI'
          )
        end
      end
    end

    context 'for CC facility' do
      context 'for VAOS' do
        before do
          allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_use_vpg, instance_of(User)).and_return(false)
        end

        it 'creates the cc appointment' do
          VCR.use_cassette('mobile/appointments/post_appointments_cc_200_2222022', match_requests_on: %i[method uri]) do
            VCR.use_cassette('mobile/appointments/VAOS_v2/get_facilities_200', match_requests_on: %i[method uri]) do
              post '/mobile/v0/appointment', params: community_cares_request_body, headers: sis_headers
              expect(response).to have_http_status(:created)
              expect(json_body_for(response)).to match_camelized_schema('vaos/v2/appointment', { strict: false })
            end
          end
        end
      end

      context 'for VPG' do
        before do
          allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_use_vpg, instance_of(User)).and_return(true)
        end

        it 'creates the cc appointment' do
          VCR.use_cassette('mobile/appointments/post_appointments_cc_200_2222022_vpg',
                           match_requests_on: %i[method uri]) do
            VCR.use_cassette('mobile/appointments/VAOS_v2/get_facilities_200', match_requests_on: %i[method uri]) do
              post '/mobile/v0/appointment', params: community_cares_request_body, headers: sis_headers
              expect(response).to have_http_status(:created)
              expect(json_body_for(response)).to match_camelized_schema('vaos/v2/appointment', { strict: false })
            end
          end
        end
      end
    end

    context 'for va facility' do
      context 'using VAOS' do
        before do
          allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_use_vpg, instance_of(User)).and_return(false)
        end

        it 'creates the va appointment - proposed' do
          VCR.use_cassette('mobile/appointments/post_appointments_va_proposed_clinic_200',
                           match_requests_on: %i[method uri]) do
            post '/mobile/v0/appointment', params: {}, headers: sis_headers
            expect(response).to have_http_status(:created)
            expect(json_body_for(response)).to match_camelized_schema('vaos/v2/appointment', { strict: false })
          end
        end

        it 'creates the va appointment - booked' do
          VCR.use_cassette('mobile/appointments/post_appointments_va_booked_200_JACQUELINE_M',
                           match_requests_on: %i[method uri]) do
            VCR.use_cassette('mobile/appointments/VAOS_v2/get_facilities_200', match_requests_on: %i[method uri]) do
              post '/mobile/v0/appointment', params: {}, headers: sis_headers
              expect(response).to have_http_status(:created)
              expect(json_body_for(response)).to match_camelized_schema('vaos/v2/appointment', { strict: false })
            end
          end
        end
      end

      context 'using VPG' do
        before do
          allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_use_vpg, instance_of(User)).and_return(true)
        end

        it 'creates the va appointment - proposed' do
          VCR.use_cassette('mobile/appointments/post_appointments_va_proposed_clinic_200_vpg',
                           match_requests_on: %i[method uri]) do
            post '/mobile/v0/appointment', params: {}, headers: sis_headers

            expect(response).to have_http_status(:created)
            expect(json_body_for(response)).to match_camelized_schema('vaos/v2/appointment', { strict: false })
          end
        end

        it 'creates the va appointment - booked' do
          VCR.use_cassette('mobile/appointments/post_appointments_va_booked_200_JACQUELINE_M_vpg',
                           match_requests_on: %i[method uri]) do
            VCR.use_cassette('mobile/appointments/VAOS_v2/get_facilities_200', match_requests_on: %i[method uri]) do
              post '/mobile/v0/appointment', params: {}, headers: sis_headers
              expect(response).to have_http_status(:created)
              expect(json_body_for(response)).to match_camelized_schema('vaos/v2/appointment', { strict: false })
            end
          end
        end
      end
    end
  end
end
