# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'vaos appointments', type: :request, skip_mvi: true do
  include SchemaMatchers

  before do
    Flipper.enable('va_online_scheduling')
    sign_in_as(current_user)
    allow_any_instance_of(VAOS::UserService).to receive(:session).and_return('stubbed_token')
  end

  let(:inflection_header) { { 'X-Key-Inflection' => 'camel' } }

  context 'loa3 user' do
    let(:current_user) { build(:user, :vaos) }

    describe 'POST appointments' do
      let(:error_detail) do
        'This appointment cannot be booked using VA Online Scheduling.  Please contact the site directly to schedule ' \
          'your appointment and advise them to <b>contact the VAOS Support Team for assistance with Clinic configurat' \
          'ion.</b> <a class="external-link" href="https://www.va.gov/find-locations/">VA Facility Locator</a>'
      end

      context 'with flipper disabled' do
        it 'does not have access' do
          skip 'VAOS V0 routes disabled'
          Flipper.disable('va_online_scheduling')
          post '/vaos/v0/appointments'

          expect(response).to have_http_status(:forbidden)
          expect(JSON.parse(response.body)['errors'].first['detail'])
            .to eq('You do not have access to online scheduling')
        end
      end

      context 'when appointment cannot be created due to conflict' do
        let(:request_body) do
          FactoryBot.build(:appointment_form, :ineligible).attributes
        end

        it 'returns bad request with detail in errors' do
          skip 'VAOS V0 routes disabled'
          VCR.use_cassette('vaos/appointments/post_appointment_409', match_requests_on: %i[method path query]) do
            allow(Rails.logger).to receive(:warn).at_least(:once)
            post '/vaos/v0/appointments', params: request_body

            expect(response).to have_http_status(:conflict)
            expect(JSON.parse(response.body)['errors'].first['detail'])
              .to eq(error_detail)
            expect(Rails.logger).to have_received(:warn).with('Direct schedule submission error',
                                                              any_args).at_least(:once)
          end
        end
      end

      context 'when appointment is invalid' do
        let(:request_body) do
          FactoryBot.build(:appointment_form, :ineligible).attributes
        end

        it 'returns bad request with detail in errors' do
          skip 'VAOS V0 routes disabled'
          VCR.use_cassette('vaos/appointments/post_appointment_400', match_requests_on: %i[method path query]) do
            expect(Rails.logger).to receive(:warn).with('Direct schedule submission error', any_args)
            expect(Rails.logger).to receive(:warn).with('VAOS service call failed!', any_args)
            expect(Rails.logger).to receive(:warn).with(
              'Clinic does not support VAOS appointment create',
              clinic_id: request_body[:clinic]['clinic_id'],
              site_code: request_body[:clinic]['site_code']
            )

            post '/vaos/v0/appointments', params: request_body

            expect(response).to have_http_status(:bad_request)
            expect(JSON.parse(response.body)['errors'].first['detail'])
              .to eq(error_detail)
          end
        end
      end

      context 'when appointment can be created' do
        let(:request_body) do
          FactoryBot.build(:appointment_form, :eligible).attributes
        end

        it 'creates the appointment' do
          skip 'VAOS V0 routes disabled'
          VCR.use_cassette('vaos/appointments/post_appointment', match_requests_on: %i[method path query]) do
            post '/vaos/v0/appointments', params: request_body

            expect(response).to have_http_status(:no_content)
            expect(response.body).to be_an_instance_of(String).and be_empty
          end
        end
      end
    end

    describe 'PUT appointments/cancel' do
      context 'with flipper disabled' do
        it 'does not have access' do
          skip 'VAOS V0 routes disabled'
          Flipper.disable('va_online_scheduling')
          put '/vaos/v0/appointments/cancel'

          expect(response).to have_http_status(:forbidden)
          expect(JSON.parse(response.body)['errors'].first['detail'])
            .to eq('You do not have access to online scheduling')
        end
      end

      context 'when request body validation fails' do
        it 'returns validation failed' do
          skip 'VAOS V0 routes disabled'
          put '/vaos/v0/appointments/cancel'

          expect(response).to have_http_status(:unprocessable_entity)
          expect(JSON.parse(response.body)['errors'].size).to eq(3)
        end
      end

      context 'when appointment cannot be cancelled' do
        let(:request_body) do
          {
            appointment_time: '11/15/19 20:00:00',
            clinic_id: '408',
            facility_id: '983',
            cancel_reason: 'whatever',
            cancel_code: '5',
            remarks: nil,
            clinic_name: nil
          }
        end

        it 'returns bad request with detail in errors' do
          skip 'VAOS V0 routes disabled'
          VCR.use_cassette('vaos/appointments/put_cancel_appointment_409', match_requests_on: %i[method path query]) do
            expect(Rails.logger).to receive(:warn).with('VAOS service call failed!', any_args).once
            expect(Rails.logger).to receive(:warn).with(
              'Clinic does not support VAOS appointment cancel',
              clinic_id: request_body[:clinic_id],
              site_code: request_body[:facility_id]
            ).once
            # We're checking that the logger is called twice to account for behavior in sentry_logging.rb lines 25-30
            expect(Rails.logger).to receive(:warn).twice
            put '/vaos/v0/appointments/cancel', params: request_body

            expect(response).to have_http_status(:conflict)
            expect(JSON.parse(response.body)['errors'].first['detail'])
              .to eq('This appointment cannot be cancelled using VA Online Scheduling.  Please contact the site direc' \
                     'tly to cancel your appointment. <a class="external-link" ' \
                     'href="https://www.va.gov/find-locations/">VA Facility Locator</a>')
          end
        end
      end

      context 'when appointment can be cancelled' do
        let(:request_body) do
          {
            appointment_time: '11/15/2019 13:00:00',
            clinic_id: '437',
            facility_id: '983',
            cancel_reason: '5',
            cancel_code: 'PC',
            remarks: '',
            clinic_name: 'CHY OPT VAR1'
          }
        end

        it 'cancels the appointment' do
          skip 'VAOS V0 routes disabled'
          VCR.use_cassette('vaos/appointments/put_cancel_appointment', match_requests_on: %i[method path query]) do
            put '/vaos/v0/appointments/cancel', params: request_body

            expect(response).to have_http_status(:no_content)
            expect(response.body).to be_an_instance_of(String).and be_empty
          end
        end
      end
    end
  end
end
