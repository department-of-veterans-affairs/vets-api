# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'V2::AppointmentsController', type: :request do
  let(:id) { 'd602d9eb-9a31-484f-9637-13ab0b507e0d' }
  let(:memory_store) { ActiveSupport::Cache.lookup_store(:memory_store) }

  before do
    allow(Rails).to receive(:cache).and_return(memory_store)
    allow(Flipper).to receive(:enabled?).with('check_in_experience_enabled').and_return(true)
    allow(Flipper).to receive(:enabled?).with('check_in_experience_mock_enabled').and_return(false)

    allow(Flipper).to receive(:enabled?).with(:check_in_experience_upcoming_appointments_enabled).and_return(true)

    Rails.cache.clear
  end

  describe 'GET `index`' do
    context 'when feature flag is off' do
      before do
        allow(Flipper).to receive(:enabled?).with(:check_in_experience_upcoming_appointments_enabled).and_return(false)
      end

      it 'returns not found' do
        get "/check_in/v2/sessions/#{id}/appointments"

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when session does not exist' do
      let(:resp) do
        {
          permissions: 'read.none',
          status: 'success',
          uuid: id
        }.to_json
      end

      it 'returns unauthorized status' do
        get "/check_in/v2/sessions/#{id}/appointments"

        expect(response).to have_http_status(:unauthorized)
      end

      it 'returns read.none permissions' do
        get "/check_in/v2/sessions/#{id}/appointments"

        expect(response.body).to eq(resp)
      end
    end

    context 'invalid params' do
      let(:session_params) do
        {
          params: {
            session: {
              uuid: id,
              dob: '1960-03-12',
              last_name: 'Johnson'
            }
          }
        }
      end

      before do
        VCR.use_cassette 'check_in/lorota/token/token_200' do
          post '/check_in/v2/sessions', **session_params
          expect(response).to have_http_status(:ok)
        end
      end

      it 'returns bad request when start date is invalid' do
        get "/check_in/v2/sessions/#{id}/appointments", params: { start: 'abc', end: '2023-12-12' }

        expect(response).to have_http_status(:bad_request)
      end

      it 'returns bad request when end date is invalid' do
        get "/check_in/v2/sessions/#{id}/appointments", params: { start: '2023-12-12', end: 'xyz' }

        expect(response).to have_http_status(:bad_request)
      end
    end

    context 'when appointment service returns successfully' do
      let(:session_params) do
        {
          params: {
            session: {
              uuid: id,
              dob: '1960-03-12',
              last_name: 'Johnson'
            }
          }
        }
      end
      let(:start_date) { '2023-11-10' }
      let(:end_date) { '2023-12-12' }
      let(:appts_response) do
        {
          data: [
            {
              id: '180766',
              type: 'appointments',
              attributes: {
                kind: 'clinic',
                status: 'booked',
                serviceType: 'amputation',
                locationId: '983GC',
                clinic: '1081',
                start: '2023-11-13T16:00:00Z',
                end: '2023-11-13T16:30:00Z',
                minutesDuration: 30
              }
            },
            {
              id: '180770',
              type: 'appointments',
              attributes: {
                kind: 'clinic',
                status: 'booked',
                serviceType: 'amputation',
                locationId: '983GC',
                clinic: '1081',
                start: '2023-12-11T16:00:00Z',
                end: '2023-12-11T16:30:00Z',
                minutesDuration: 30
              }
            }
          ]
        }.to_json
      end

      before do
        VCR.use_cassette 'check_in/lorota/token/token_200' do
          post '/check_in/v2/sessions', **session_params
          expect(response).to have_http_status(:ok)
        end

        VCR.use_cassette('check_in/lorota/data/data_200', match_requests_on: [:host]) do
          VCR.use_cassette 'check_in/chip/set_echeckin_started/set_echeckin_started_200' do
            VCR.use_cassette 'check_in/chip/token/token_200' do
              get "/check_in/v2/patient_check_ins/#{id}"
              expect(response).to have_http_status(:ok)
            end
          end
        end
      end

      it 'returns appointments' do
        VCR.use_cassette 'check_in/appointments/get_appointments' do
          VCR.use_cassette 'check_in/map/security_token_service_200_response' do
            get "/check_in/v2/sessions/#{id}/appointments", params: { start: start_date, end: end_date }
          end
        end

        expect(response).to have_http_status(:ok)
        expect(response.body).to eq(appts_response)
      end
    end
  end
end
