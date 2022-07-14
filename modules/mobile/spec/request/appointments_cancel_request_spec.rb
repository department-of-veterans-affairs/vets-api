# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/iam_session_helper'
require_relative '../support/matchers/json_schema_matcher'

RSpec.describe 'appointments', type: :request do
  include JsonSchemaMatchers

  before do
    allow_any_instance_of(IAMUser).to receive(:icn).and_return('24811694708759028')
    iam_sign_in(build(:iam_user))
    allow_any_instance_of(VAOS::UserService).to receive(:session).and_return('stubbed_token')
  end

  before(:all) do
    @original_cassette_dir = VCR.configure(&:cassette_library_dir)
    VCR.configure { |c| c.cassette_library_dir = 'modules/mobile/spec/support/vcr_cassettes' }
  end

  after(:all) { VCR.configure { |c| c.cassette_library_dir = @original_cassette_dir } }

  describe 'PUT /mobile/v0/appointments/cancel', :aggregate_failures do
    context 'when using VAOS v0 services' do
      before do
        Flipper.disable(:mobile_appointment_use_VAOS_v2)
      end

      context 'confirmed appointments' do
        let(:cancel_id) do
          Mobile::V0::Appointment.encode_cancel_id(
            start_date_local: DateTime.parse('2019-11-15T13:00:00'),
            clinic_id: '437',
            facility_id: '983',
            healthcare_service: 'CHY VISUAL FIELD'
          )
        end

        it 'cancels the appointment' do
          VCR.use_cassette('appointments/put_cancel_appointment', match_requests_on: %i[method uri]) do
            VCR.use_cassette('appointments/get_cancel_reasons', match_requests_on: %i[method uri]) do
              expect(Mobile::V0::Appointment).to receive(:clear_cache).once

              put "/mobile/v0/appointments/cancel/#{cancel_id}", headers: iam_headers
              expect(response).to have_http_status(:no_content)
              expect(response.body).to be_an_instance_of(String).and be_empty
            end
          end
        end

        context 'invalid cancel id format' do
          let(:cancel_id) { 'abc123' }

          it 'returns a 422 that lists all validation errors' do
            VCR.use_cassette('appointments/get_cancel_reasons', match_requests_on: %i[method uri]) do
              put "/mobile/v0/appointments/cancel/#{cancel_id}", headers: iam_headers

              expect(response).to have_http_status(:unprocessable_entity)
              expect(response.body).to match_json_schema('errors')
              expect(response.parsed_body['errors'].size).to eq(1)
            end
          end
        end

        context 'when the cancel reason service does not return a valid reason' do
          it 'returns not found code with detail in errors' do
            VCR.use_cassette('appointments/get_cancel_reasons_invalid', match_requests_on: %i[method uri]) do
              put "/mobile/v0/appointments/cancel/#{cancel_id}", headers: iam_headers

              expect(response).to have_http_status(:not_found)
              expect(response.parsed_body['errors'].first['detail']).to eq(
                'This appointment can not be cancelled online because a prerequisite cancel reason could not be found'
              )
            end
          end
        end

        context 'when cancel reason returns a 500' do
          it 'returns bad gateway code with detail in errors' do
            VCR.use_cassette('appointments/get_cancel_reasons_500', match_requests_on: %i[method uri]) do
              put "/mobile/v0/appointments/cancel/#{cancel_id}", headers: iam_headers
              expect(response).to have_http_status(:bad_gateway)
              expect(response.parsed_body['errors'].first['detail'])
                .to eq('Received an an invalid response from the upstream server')
            end
          end
        end

        context 'when appointment cannot be cancelled online' do
          it 'returns bad request with detail in errors' do
            VCR.use_cassette('appointments/put_cancel_appointment_409', match_requests_on: %i[method uri]) do
              VCR.use_cassette('appointments/get_cancel_reasons', match_requests_on: %i[method uri]) do
                expect_any_instance_of(SentryLogging).not_to receive(:log_exception_to_sentry)

                put "/mobile/v0/appointments/cancel/#{cancel_id}", headers: iam_headers

                expect(response).to have_http_status(:conflict)
                expect(response.parsed_body['errors'].first['detail'])
                  .to eq('The facility does not support online scheduling or cancellation of appointments')
              end
            end
          end
        end

        context 'when appointment fails cancellation' do
          let(:cancel_id) do
            Mobile::V0::Appointment.encode_cancel_id(
              start_date_local: DateTime.parse('2019-11-20T17:00:00'),
              clinic_id: '437',
              facility_id: '983',
              healthcare_service: 'CHY VISUAL FIELD'
            )
          end

          it 'returns a bad gateway code' do
            VCR.use_cassette('appointments/put_cancel_appointment_500', match_requests_on: %i[method uri]) do
              VCR.use_cassette('appointments/get_cancel_reasons', match_requests_on: %i[method uri]) do
                put "/mobile/v0/appointments/cancel/#{cancel_id}", headers: iam_headers

                expect(response).to have_http_status(:bad_gateway)
                expect(response.body).to match_json_schema('errors')
              end
            end
          end
        end
      end

      context 'appointment requests' do
        let(:va_cancel_id) { '8a4891c97ec0fb13017f56ea721d00a0' }
        let(:cc_cancel_id) { '8a483a787dd718d6017e036e9c0d000a' }
        let(:user) { build(:iam_user) }

        it 'cancels the va appointment and clears cache' do
          VCR.use_cassette('appointments/get_appointment_request', match_requests_on: %i[method uri]) do
            VCR.use_cassette('appointments/put_cancel_appointment_request', match_requests_on: %i[method uri]) do
              expect(Mobile::V0::Appointment).to receive(:clear_cache).once

              put "/mobile/v0/appointments/cancel/#{va_cancel_id}", headers: iam_headers
              expect(response).to have_http_status(:no_content)
              expect(response.body).to be_an_instance_of(String).and be_empty
            end
          end
        end

        it 'cancels the cc appointment and clears cache' do
          VCR.use_cassette('appointments/get_cc_appointment_request', match_requests_on: %i[method uri]) do
            VCR.use_cassette('appointments/put_cancel_cc_appointment_request', match_requests_on: %i[method uri]) do
              expect(Mobile::V0::Appointment).to receive(:clear_cache).once

              put "/mobile/v0/appointments/cancel/#{cc_cancel_id}", headers: iam_headers
              expect(response).to have_http_status(:no_content)
              expect(response.body).to be_an_instance_of(String).and be_empty
            end
          end
        end

        context 'when a appointment cannot be cancelled online' do
          it 'returns conflict code with detail in errors' do
            VCR.use_cassette('appointments/get_appointment_request', match_requests_on: %i[method uri]) do
              VCR.use_cassette('appointments/put_cancel_appointment_request_409',
                               match_requests_on: %i[method uri]) do
                expect_any_instance_of(SentryLogging).not_to receive(:log_exception_to_sentry)

                put "/mobile/v0/appointments/cancel/#{va_cancel_id}", headers: iam_headers

                expect(response).to have_http_status(:conflict)
                expect(response.parsed_body['errors'].first['detail'])
                  .to eq('The facility does not support online scheduling or cancellation of appointments')
              end
            end
          end
        end

        context 'when appointment fails cancellation' do
          it 'returns a 502 code' do
            VCR.use_cassette('appointments/get_appointment_request', match_requests_on: %i[method uri]) do
              VCR.use_cassette('appointments/put_cancel_appointment_request_500',
                               match_requests_on: %i[method uri]) do
                put "/mobile/v0/appointments/cancel/#{va_cancel_id}", headers: iam_headers
                expect(response).to have_http_status(:bad_gateway)
                expect(response.body).to match_json_schema('errors')
              end
            end
          end
        end

        context 'when appointment does not have submitted status' do
          it 'cancels the appointment' do
            VCR.use_cassette('appointments/get_appointment_request_cancelled', match_requests_on: %i[method uri]) do
              VCR.use_cassette('appointments/put_cancel_appointment_request', match_requests_on: %i[method uri]) do
                put "/mobile/v0/appointments/cancel/#{va_cancel_id}", headers: iam_headers
                expect(response).to have_http_status(:no_content)
              end
            end
          end
        end

        context 'when appointment id does not exist' do
          it 'returns a 404 code' do
            VCR.use_cassette('appointments/get_appointment_request_404', match_requests_on: %i[method uri]) do
              put "/mobile/v0/appointments/cancel/#{va_cancel_id}", headers: iam_headers
              expect(response).to have_http_status(:not_found)
              expect(response.body).to match_json_schema('errors')
            end
          end
        end
      end
    end

    context 'when using VAOS v2 services' do
      before { Flipper.enable(:mobile_appointment_use_VAOS_v2) }

      after { Flipper.disable(:mobile_appointment_use_VAOS_v2) }

      let(:cancel_id) { '70060' }

      it 'returns a no content code' do
        VCR.use_cassette('appointments/VAOS_v2/cancel_appointment_200', match_requests_on: %i[method uri]) do
          put "/mobile/v0/appointments/cancel/#{cancel_id}", params: { status: 'cancelled' }, headers: iam_headers

          expect(response).to have_http_status(:no_content)
          expect(response.body).to be_an_instance_of(String).and be_empty
        end
      end

      context 'when the appointment cannot be found' do
        it 'returns a 400 code' do
          VCR.use_cassette('appointments/VAOS_v2/cancel_appointment_400', match_requests_on: %i[method uri]) do
            put "/mobile/v0/appointments/cancel/#{cancel_id}", params: { status: 'cancelled' }, headers: iam_headers

            expect(response.status).to eq(400)
            expect(response.parsed_body.dig('errors', 0, 'code')).to eq('VAOS_400')

            error_message = JSON.parse(response.parsed_body.dig('errors', 0, 'source', 'vamfBody'))['message']
            expect(error_message).to eq('appointment may not be cancelled')
          end
        end
      end

      context 'when the backend service cannot handle the request' do
        it 'returns a 502 code' do
          VCR.use_cassette('appointments/VAOS_v2/cancel_appointment_500', match_requests_on: %i[method uri]) do
            put "/mobile/v0/appointments/cancel/#{cancel_id}", params: { status: 'cancelled' }, headers: iam_headers
            expect(response.status).to eq(502)
            expect(JSON.parse(response.body)['errors'][0]['code']).to eq('VAOS_502')

            error_message = JSON.parse(response.parsed_body.dig('errors', 0, 'source', 'vamfBody'))['message']
            expect(error_message).to eq('failed to cancel appointment')
          end
        end
      end
    end
  end
end
