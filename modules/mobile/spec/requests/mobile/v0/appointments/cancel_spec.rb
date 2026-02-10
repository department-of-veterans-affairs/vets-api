# frozen_string_literal: true

require_relative '../../../../support/helpers/rails_helper'

RSpec.describe 'Mobile::V0::Appointments::Cancel', type: :request do
  include JsonSchemaMatchers

  let!(:user) { sis_user(icn: '24811694708759028') }
  let(:cancel_id) { '70060' }

  before do
    allow_any_instance_of(User).to receive(:va_patient?).and_return(true)
    allow_any_instance_of(VAOS::UserService).to receive(:session).and_return('stubbed_token')
    allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_vaos_alternate_route).and_return(false)
  end

  describe 'authorization' do
    context 'when user does not have access' do
      let!(:user) { sis_user(:api_auth, :loa1, icn: nil) }

      it 'returns forbidden' do
        put "/mobile/v0/appointments/cancel/#{cancel_id}", params: nil, headers: sis_headers
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'using VAOS' do
      before do
        allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_use_vpg, instance_of(User)).and_return(false)
        allow(Flipper).to receive(:enabled?).with(:travel_pay_view_claim_details, instance_of(User)).and_return(false)
      end

      it 'returns no content' do
        VCR.use_cassette('mobile/appointments/VAOS_v2/cancel_appointment_200', match_requests_on: %i[method uri]) do
          VCR.use_cassette('mobile/appointments/VAOS_v2/get_facilities_200', match_requests_on: %i[method uri]) do
            put "/mobile/v0/appointments/cancel/#{cancel_id}", params: nil, headers: sis_headers

            expect(response).to have_http_status(:no_content)
          end
        end
      end

      context 'using VPG' do
        before do
          allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_use_vpg, instance_of(User)).and_return(true)
          allow(Flipper).to receive(:enabled?).with(:travel_pay_view_claim_details, instance_of(User)).and_return(false)
        end

        it 'returns no content' do
          VCR.use_cassette('mobile/appointments/VAOS_v2/cancel_appointment_vpg_204',
                           match_requests_on: %i[method uri]) do
            VCR.use_cassette('mobile/appointments/VAOS_v2/get_appointment_cancelled_200_vpg',
                             match_requests_on: %i[method uri]) do
              VCR.use_cassette('mobile/appointments/VAOS_v2/get_facilities_200', match_requests_on: %i[method uri]) do
                put "/mobile/v0/appointments/cancel/#{cancel_id}", params: nil, headers: sis_headers

                expect(response).to have_http_status(:no_content)
              end
            end
          end
        end
      end
    end
  end

  context 'using vaos-service' do
    before do
      allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_use_vpg, instance_of(User)).and_return(false)
      allow(Flipper).to receive(:enabled?).with(:travel_pay_view_claim_details, instance_of(User)).and_return(false)
    end

    describe 'PUT /mobile/v0/appointments/cancel', :aggregate_failures do
      it 'returns a no content code' do
        VCR.use_cassette('mobile/appointments/VAOS_v2/cancel_appointment_200', match_requests_on: %i[method uri]) do
          VCR.use_cassette('mobile/appointments/VAOS_v2/get_facilities_200', match_requests_on: %i[method uri]) do
            put "/mobile/v0/appointments/cancel/#{cancel_id}", params: nil, headers: sis_headers

            expect(response).to have_http_status(:no_content)
            expect(response.body).to be_an_instance_of(String).and be_empty
          end
        end
      end

      context 'when the appointment cannot be found' do
        it 'returns a 400 code' do
          VCR.use_cassette('mobile/appointments/VAOS_v2/cancel_appointment_400', match_requests_on: %i[method uri]) do
            put "/mobile/v0/appointments/cancel/#{cancel_id}", params: nil, headers: sis_headers

            expect(response).to have_http_status(:bad_request)
            expect(response.parsed_body.dig('errors', 0, 'code')).to eq('VAOS_400')

            error_message = JSON.parse(response.parsed_body.dig('errors', 0, 'source', 'vamfBody'))['message']
            expect(error_message).to eq('appointment may not be cancelled')
          end
        end
      end

      context 'when the backend service cannot handle the request' do
        it 'returns a 502 code' do
          VCR.use_cassette('mobile/appointments/VAOS_v2/cancel_appointment_500', match_requests_on: %i[method uri]) do
            put "/mobile/v0/appointments/cancel/#{cancel_id}", params: nil, headers: sis_headers
            expect(response).to have_http_status(:bad_gateway)
            expect(JSON.parse(response.body)['errors'][0]['code']).to eq('VAOS_502')

            error_message = JSON.parse(response.parsed_body.dig('errors', 0, 'source', 'vamfBody'))['message']
            expect(error_message).to eq('failed to cancel appointment')
          end
        end
      end
    end
  end

  context 'using vpg' do
    before do
      allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_use_vpg, instance_of(User)).and_return(true)
      allow(Flipper).to receive(:enabled?).with(:travel_pay_view_claim_details, instance_of(User)).and_return(false)
    end

    describe 'PUT /mobile/v0/appointments/cancel', :aggregate_failures do
      it 'returns a no content code' do
        VCR.use_cassette('mobile/appointments/VAOS_v2/cancel_appointment_vpg_204', match_requests_on: %i[method uri]) do
          VCR.use_cassette('mobile/appointments/VAOS_v2/get_appointment_cancelled_200_vpg',
                           match_requests_on: %i[method uri]) do
            VCR.use_cassette('mobile/appointments/VAOS_v2/get_facilities_200', match_requests_on: %i[method uri]) do
              put "/mobile/v0/appointments/cancel/#{cancel_id}", params: nil, headers: sis_headers

              expect(response).to have_http_status(:no_content)
              expect(response.body).to be_an_instance_of(String).and be_empty
            end
          end
        end
      end

      context 'when the appointment cannot be found' do
        it 'returns a 400 code' do
          VCR.use_cassette('mobile/appointments/VAOS_v2/cancel_appointment_vpg_400',
                           match_requests_on: %i[method uri]) do
            put "/mobile/v0/appointments/cancel/#{cancel_id}", params: nil, headers: sis_headers

            expect(response).to have_http_status(:bad_request)
            expect(response.parsed_body.dig('errors', 0, 'code')).to eq('VAOS_400')

            error_message = JSON.parse(response.parsed_body.dig('errors', 0, 'source', 'vamfBody'))['message']
            expect(error_message).to eq('appointment may not be cancelled')
          end
        end
      end

      context 'when the backend service cannot handle the request' do
        it 'returns a 502 code' do
          VCR.use_cassette('mobile/appointments/VAOS_v2/cancel_appointment_vpg_500',
                           match_requests_on: %i[method uri]) do
            put "/mobile/v0/appointments/cancel/#{cancel_id}", params: nil, headers: sis_headers
            expect(response).to have_http_status(:bad_gateway)
            expect(JSON.parse(response.body)['errors'][0]['code']).to eq('VAOS_502')

            error_message = JSON.parse(response.parsed_body.dig('errors', 0, 'source', 'vamfBody'))['message']
            expect(error_message).to eq('failed to cancel appointment')
          end
        end
      end
    end
  end
end
