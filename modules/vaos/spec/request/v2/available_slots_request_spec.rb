# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Available Slots Request', type: :request do
  include SchemaMatchers

  before do
    Flipper.enable('va_online_scheduling')
    sign_in_as(user)
    allow_any_instance_of(VAOS::UserService).to receive(:session).and_return('stubbed_token')
  end

  let(:inflection_header) { { 'X-Key-Inflection' => 'camel' } }

  context 'with a loa3 user' do
    let(:user) { build(:user, :mhv) }

    describe 'GET available appointment slots' do
      context 'on a successful request' do
        it 'returns list of available slots' do
          VCR.use_cassette('vaos/v2/systems/get_available_slots_200', match_requests_on: %i[method uri]) do
            get '/vaos/v2/locations/534gd/clinics/333/slots?start=2020-01-01T00:00:00Z&end=2020-12-31T23:59:59Z'
            expect(response).to have_http_status(:ok)
            expect(response).to match_response_schema('vaos/v2/slots', { strict: false })

            slots = JSON.parse(response.body)['data']
            expect(slots.size).to eq(3)
            slot = slots[1]
            expect(slot['id']).to eq('ce1c5976-e96c-4e9b-9fed-ca1150cf4296')
            expect(slot['type']).to eq('slots')
            expect(slot['attributes']['start']).to eq('2020-01-01T12:30:00Z')
            expect(slot['attributes']['end']).to eq('2020-01-01T13:00:00Z')
          end
        end
      end

      context 'on a backend service error' do
        it 'returns a 502 status code' do
          VCR.use_cassette('vaos/v2/systems/get_available_slots_500', match_requests_on: %i[method uri]) do
            get '/vaos/v2/locations/534gd/clinics/333/slots?start=2020-01-01T00:00:00Z&end=2020-12-31T23:59:59Z'
            expect(response).to have_http_status(:bad_gateway)
            expect(JSON.parse(response.body)['errors'][0]['detail'])
              .to eq('Received an an invalid response from the upstream server')
          end
        end
      end
    end
  end
end
