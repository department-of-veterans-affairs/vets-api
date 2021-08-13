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

    describe 'CREATE appointment' do
      let(:request_body) do
        FactoryBot.build(:appointment_form_v2, :eligible).attributes
      end

      it 'creates the appointment' do
        VCR.use_cassette('vaos/v2/appointments/post_appointments_200', match_requests_on: %i[method uri]) do
          post '/vaos/v2/appointments', params: request_body, headers: inflection_header
          expect(response).to have_http_status(:created)
          expect(json_body_for(response)).to match_camelized_schema('vaos/v2/appointment', { strict: false })
        end
      end

      it 'returns a 400 error' do
        VCR.use_cassette('vaos/v2/appointments/post_appointments_400', match_requests_on: %i[method uri]) do
          post '/vaos/v2/appointments', params: request_body
          expect(response).to have_http_status(:bad_request)
          expect(JSON.parse(response.body)['errors'][0]['status']).to eq('400')
          expect(JSON.parse(response.body)['errors'][0]['detail']).to eq(
            'the patientIcn must match the ICN in the request URI'
          )
        end
      end
    end

    describe 'GET appointments' do
      let(:start_date) { Time.zone.parse('2021-05-16T19:25:00Z') }
      let(:end_date) { Time.zone.parse('2021-09-16T19:45:00Z') }
      let(:params) { { start: start_date, end: end_date } }

      context 'requests a list of appointments' do
        it 'has access and returns va appointments' do
          VCR.use_cassette('vaos/v2/appointments/get_appointments_200', match_requests_on: %i[method uri]) do
            get '/vaos/v2/appointments', params: params, headers: inflection_header

            expect(response).to have_http_status(:ok)
            expect(response.body).to be_a(String)
            expect(JSON.parse(response.body)['data'].size).to eq(84)
            expect(response).to match_camelized_response_schema('vaos/v2/appointments', { strict: false })
          end
        end

        it 'has access and returns va appointments given a date range and single status' do
          VCR.use_cassette('vaos/v2/appointments/get_appointments_single_status_200',
                           match_requests_on: %i[method uri]) do
            get '/vaos/v2/appointments?start=2021-05-16T19:25:00Z&end=2021-09-16T19:45:00Z&statuses=proposed',
                headers: inflection_header
            expect(response).to match_camelized_response_schema('vaos/v2/appointments', { strict: false })
            data = JSON.parse(response.body)['data']
            expect(data.size).to eq(3)
            expect(data[0]['attributes']['status']).to eq('proposed')
            expect(data[1]['attributes']['status']).to eq('proposed')
          end
        end

        it 'has access and returns va appointments given date a range and single status (as array)' do
          VCR.use_cassette('vaos/v2/appointments/get_appointments_single_status_200',
                           match_requests_on: %i[method uri]) do
            get '/vaos/v2/appointments?start=2021-05-16T19:25:00Z&end=2021-09-16T19:45:00Z&statuses[]=proposed',
                headers: inflection_header
            expect(response).to match_camelized_response_schema('vaos/v2/appointments', { strict: false })
            data = JSON.parse(response.body)['data']
            expect(data.size).to eq(3)
            expect(data[0]['attributes']['status']).to eq('proposed')
            expect(data[1]['attributes']['status']).to eq('proposed')
          end
        end

        it 'has access and returns va appointments given a date range and multiple statuses' do
          VCR.use_cassette('vaos/v2/appointments/get_appointments_multi_status_200',
                           match_requests_on: %i[method uri]) do
            get '/vaos/v2/appointments?start=2021-05-16T19:25:00Z&end=2021-09-16T19:45:00Z&statuses=proposed,booked',
                headers: inflection_header
            expect(response).to have_http_status(:ok)
            expect(response).to match_camelized_response_schema('vaos/v2/appointments', { strict: false })
            data = JSON.parse(response.body)['data']
            expect(data.size).to eq(17)
            expect(data[0]['attributes']['status']).to eq('booked')
            expect(data[16]['attributes']['status']).to eq('proposed')
          end
        end

        it 'has access and returns va appointments given a date range and multiple statuses (as Array)' do
          VCR.use_cassette('vaos/v2/appointments/get_appointments_multi_status_200',
                           match_requests_on: %i[method uri]) do
            get '/vaos/v2/appointments?start=2021-05-16T19:25:00Z&end=2021-09-16T19:45:00Z&statuses[]=proposed' \
                '&statuses[]=booked',
                headers: inflection_header
            expect(response).to have_http_status(:ok)
            expect(response).to match_camelized_response_schema('vaos/v2/appointments', { strict: false })
            data = JSON.parse(response.body)['data']
            expect(data.size).to eq(17)
            expect(data[0]['attributes']['status']).to eq('booked')
            expect(data[16]['attributes']['status']).to eq('proposed')
          end
        end

        it 'returns a 400 error' do
          VCR.use_cassette('vaos/v2/appointments/get_appointments_400', match_requests_on: %i[method uri]) do
            get '/vaos/v2/appointments', params: { start: start_date }

            expect(response).to have_http_status(:bad_request)
            expect(JSON.parse(response.body)['errors'][0]['status']).to eq('400')
          end
        end
      end
    end

    describe 'GET appointment' do
      context 'when the VAOS service returns a single appointment' do
        it 'has access and returns appointment' do
          VCR.use_cassette('vaos/v2/appointments/get_appointment_200', match_requests_on: %i[method uri]) do
            get '/vaos/v2/appointments/36952', headers: inflection_header
            expect(response).to have_http_status(:ok)
            expect(json_body_for(response)).to match_camelized_schema('vaos/v2/appointment', { strict: false })
            data = JSON.parse(response.body)['data']
            expect(data['id']).to eq('36952')
            expect(data['attributes']['status']).to eq('booked')
            expect(data['attributes']['minutesDuration']).to eq(20)
          end
        end
      end

      context 'when the VAOS service errors on retrieving an appointment' do
        it 'returns a 502 status code' do
          VCR.use_cassette('vaos/v2/appointments/get_appointment_500', match_requests_on: %i[method uri]) do
            get '/vaos/v2/appointments/no_such_appointment'
            expect(response).to have_http_status(:bad_gateway)
            expect(JSON.parse(response.body)['errors'][0]['code']).to eq('VAOS_502')
          end
        end
      end
    end

    describe 'Cancel appointments' do
      context 'when the appointment is successfully cancelled' do
        it 'returns a status code of 200 and the cancelled appointment with the updated status' do
          VCR.use_cassette('vaos/v2/appointments/cancel_appointments_200', match_requests_on: %i[method uri]) do
            put '/vaos/v2/appointments/cancel/42081?reason=test cancellation'
            expect(response.status).to eq(200)
            expect(JSON.parse(response.body)['data']['attributes']['status']).to eq('cancelled')
          end
        end
      end

      context 'when the backend service cannot handle the request' do
        it 'returns a 502 status code' do
          VCR.use_cassette('vaos/v2/appointments/cancel_appointments_500', match_requests_on: %i[method uri]) do
            put '/vaos/v2/appointments/cancel/35952?reason=test reason'
            expect(response.status).to eq(502)
            expect(JSON.parse(response.body)['errors'][0]['code']).to eq('VAOS_502')
          end
        end
      end
    end
  end
end
