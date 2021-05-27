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
        VCR.use_cassette('vaos/v2/appointments/post_appointments', match_requests_on: %i[method uri]) do
          post '/vaos/v2/appointments', params: request_body
          expect(response).to have_http_status(:created)
          expect(json_body_for(response)).to match_schema('vaos/v2/appointment', { strict: false })
        end
      end
    end

    describe 'GET appointments' do
      let(:start_date) { Time.zone.parse('2020-06-02T07:00:00Z') }
      let(:end_date) { Time.zone.parse('2020-07-02T08:00:00Z') }
      let(:params) { { start: start_date, end: end_date } }

      context 'returns list of appointments' do
        it 'has access and returns va appointments' do
          VCR.use_cassette('vaos/v2/appointments/get_appointments', match_requests_on: %i[method uri]) do
            get '/vaos/v2/appointments', params: params

            expect(response).to have_http_status(:ok)
            expect(response.body).to be_a(String)
            expect(JSON.parse(response.body)['data'].size).to eq(1)
            expect(response).to match_response_schema('vaos/v2/appointments', { strict: false })
          end
        end
      end
    end

    describe 'GET appointment' do
      context 'when the VAOS service returns a single appointment' do
        it 'has access and returns appointment' do
          VCR.use_cassette('vaos/v2/appointments/get_appointment_200', match_requests_on: %i[method uri]) do
            get '/vaos/v2/appointments/20029'
            expect(response).to have_http_status(:ok)
            expect(json_body_for(response)).to match_schema('vaos/v2/appointment', { strict: false })
            data = JSON.parse(response.body)['data']
            expect(data['id']).to eq('20029')
            expect(data['attributes']['status']).to eq('booked')
            expect(data['attributes']['minutes_duration']).to eq(20)
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

    describe 'PUT appointments' do
      context 'when the appointment status is updated' do
        it 'returns a status code of 200 and the updated appointment in the body' do
          VCR.use_cassette('vaos/v2/appointments/put_appointments_200', match_requests_on: %i[method uri]) do
            # TODO: update spec with live VAOS recordings
            put '/vaos/v2/appointments/1121?status=cancelled'
            expect(response).to have_http_status(:ok)
            expect(JSON.parse(response.body)['data']['attributes']['status']).to eq('cancelled')
            expect(json_body_for(response)).to match_schema('vaos/v2/appointment', { strict: false })
          end
        end
      end

      context 'when the upstream service recieves a bad update request' do
        it 'returns a 400 status code' do
          VCR.use_cassette('vaos/v2/appointments/put_appointments_400', match_requests_on: %i[method uri]) do
            put '/vaos/v2/appointments/1121?status=cancelled'
            expect(response.status).to eq(400)
            expect(JSON.parse(response.body)['errors'][0]['source']['vamf_status']).to eq(400)
          end
        end
      end
    end
  end
end
