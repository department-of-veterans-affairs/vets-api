# frozen_string_literal: true

require 'rails_helper'
RSpec.describe 'vaos appointments', type: :request, skip_mvi: true do
  include SchemaMatchers

  before do
    Flipper.enable('va_online_scheduling')
    sign_in_as(current_user)
    allow_any_instance_of(VAOS::UserService).to receive(:session).and_return('stubbed_token')
  end

  context 'loa1 user' do
    let(:current_user) { build(:user, :loa1) }

    describe 'GET appointments' do
      it 'does not have access' do
        get '/v0/vaos/appointments'
        expect(response).to have_http_status(:forbidden)
        expect(JSON.parse(response.body)['errors'].first['detail'])
          .to eq('You do not have access to online scheduling')
      end
    end

    describe 'PUT appointments/cancel' do
      it 'does not have access' do
        put '/v0/vaos/appointments/cancel'
        expect(response).to have_http_status(:forbidden)
        expect(JSON.parse(response.body)['errors'].first['detail'])
          .to eq('You do not have access to online scheduling')
      end
    end
  end

  context 'loa3 user' do
    let(:current_user) { build(:user, :vaos) }

    describe 'GET appointments' do
      let(:start_date) { Time.zone.parse('2019-11-14T07:00:00Z') }
      let(:end_date) { Time.zone.parse('2020-03-14T08:00:00Z') }
      let(:params) { { type: 'va', start_date: start_date, end_date: end_date } }

      context 'with flipper disabled' do
        it 'does not have access' do
          Flipper.disable('va_online_scheduling')
          get '/v0/vaos/appointments'
          expect(response).to have_http_status(:forbidden)
          expect(JSON.parse(response.body)['errors'].first['detail'])
            .to eq('You do not have access to online scheduling')
        end
      end

      context 'without icn' do
        before { stub_mvi_not_found }

        let(:current_user) { build(:user, :mhv, mhv_icn: nil) }

        it 'does not have access' do
          get '/v0/vaos/appointments'
          expect(response).to have_http_status(:forbidden)
          expect(JSON.parse(response.body)['errors'].first['detail'])
            .to eq('No patient ICN found')
        end
      end

      context 'without a type' do
        it 'has a parameter missing exception' do
          get '/v0/vaos/appointments', params: params.except(:type)
          expect(response).to have_http_status(:bad_request)
          expect(response.body).to be_a(String)
          expect(JSON.parse(response.body)['errors'].first['detail'])
            .to eq('The required parameter "type", is missing')
        end
      end

      context 'without a start_date' do
        it 'has a parameter missing exception' do
          get '/v0/vaos/appointments', params: params.except(:start_date)
          expect(response).to have_http_status(:bad_request)
          expect(response.body).to be_a(String)
          expect(JSON.parse(response.body)['errors'].first['detail'])
            .to eq('The required parameter "start_date", is missing')
        end
      end

      context 'without an end_date' do
        it 'has a parameter missing exception' do
          get '/v0/vaos/appointments', params: params.except(:end_date)
          expect(response).to have_http_status(:bad_request)
          expect(response.body).to be_a(String)
          expect(JSON.parse(response.body)['errors'].first['detail'])
            .to eq('The required parameter "end_date", is missing')
        end
      end

      context 'with an invalid type' do
        it 'has an invalid field type exception' do
          get '/v0/vaos/appointments', params: params.merge(type: 'invalid')
          expect(response).to have_http_status(:bad_request)
          expect(response.body).to be_a(String)
          expect(JSON.parse(response.body)['errors'].first['detail'])
            .to eq('"invalid" is not a valid value for "type"')
        end
      end

      context 'with an invalid start_date' do
        it 'has an invalid field type exception' do
          get '/v0/vaos/appointments', params: params.merge(start_date: 'invalid')
          expect(response).to have_http_status(:bad_request)
          expect(response.body).to be_a(String)
          expect(JSON.parse(response.body)['errors'].first['detail'])
            .to eq('"invalid" is not a valid value for "start_date"')
        end
      end

      context 'with an invalid end_date' do
        it 'has an invalid field type exception' do
          get '/v0/vaos/appointments', params: params.merge(end_date: 'invalid')
          expect(response).to have_http_status(:bad_request)
          expect(response.body).to be_a(String)
          expect(JSON.parse(response.body)['errors'].first['detail'])
            .to eq('"invalid" is not a valid value for "end_date"')
        end
      end

      it 'has access and returns va appointments' do
        VCR.use_cassette('vaos/appointments/get_appointments', match_requests_on: %i[method uri]) do
          get '/v0/vaos/appointments', params: params

          expect(response).to have_http_status(:success)
          expect(response.body).to be_a(String)
          expect(response).to match_response_schema('vaos/va_appointments')
        end
      end

      it 'has access and returns cc appointments' do
        VCR.use_cassette('vaos/appointments/get_cc_appointments', match_requests_on: %i[method uri]) do
          get '/v0/vaos/appointments', params: params.merge(type: 'cc')

          expect(response).to have_http_status(:success)
          expect(response.body).to be_a(String)
          expect(response).to match_response_schema('vaos/cc_appointments')
        end
      end
    end

    describe 'PUT appointments/cancel' do
      context 'with flipper disabled' do
        it 'does not have access' do
          Flipper.disable('va_online_scheduling')
          put '/v0/vaos/appointments/cancel'

          expect(response).to have_http_status(:forbidden)
          expect(JSON.parse(response.body)['errors'].first['detail'])
            .to eq('You do not have access to online scheduling')
        end
      end

      context 'when request body validation fails' do
        it 'returns validation failed' do
          put '/v0/vaos/appointments/cancel'

          expect(response).to have_http_status(:unprocessable_entity)
          expect(JSON.parse(response.body)['errors'].size).to eq(2)
        end
      end

      context 'when appointment cannot be cancelled' do
        let(:request_body) do
          {
            appointment_time: '11/15/19 20:00:00',
            clinic_id: '408',
            cancel_reason: 'whatever',
            cancel_code: '5',
            remarks: nil,
            clinic_name: nil
          }
        end

        it 'returns bad request with detail in errors' do
          VCR.use_cassette('vaos/appointments/put_cancel_appointment_400', match_requests_on: %i[method uri]) do
            put '/v0/vaos/appointments/cancel', params: request_body

            expect(response).to have_http_status(:bad_request)
            expect(JSON.parse(response.body)['errors'].first['detail'])
              .to eq('This appointment cannot be cancelled using VA Online Scheduling.  Please contact the site direc' \
                'tly to cancel your appointment. <a class="external-link" href="https://www.va.gov/find-locations/">V' \
                'A Facility Locator</a>')
          end
        end
      end

      context 'when appointment can be cancelled' do
        let(:request_body) do
          {
            appointment_time: '11/15/2019 13:00:00',
            clinic_id: '437',
            cancel_reason: '5',
            cancel_code: 'PC',
            remarks: '',
            clinic_name: 'CHY OPT VAR1'
          }
        end

        it 'cancels the appointment' do
          VCR.use_cassette('vaos/appointments/put_cancel_appointment', match_requests_on: %i[method uri]) do
            put '/v0/vaos/appointments/cancel', params: request_body

            expect(response).to have_http_status(:success)
            expect(response.body).to be_an_instance_of(String).and be_empty
          end
        end
      end
    end
  end
end
