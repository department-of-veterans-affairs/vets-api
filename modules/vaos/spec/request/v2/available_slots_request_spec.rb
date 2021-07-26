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

  context 'with a loa3 user', :skip_mvi do
    let(:user) { build(:user, :vaos) }

    describe 'GET available appointment slots' do
      context 'on a successful request' do
        it 'returns list of available slots' do
          VCR.use_cassette('vaos/v2/systems/get_available_slots_200', match_requests_on: %i[method uri]) do
            get '/vaos/v2/locations/983/clinics/1081/slots?start=2021-05-26T00:00:00Z&end=2021-06-30T23:59:59Z',
                headers: inflection_header
            expect(response).to have_http_status(:ok)
            expect(response.body).to match_camelized_schema('vaos/v2/slots', { strict: false })

            slots = JSON.parse(response.body)['data']
            expect(slots.size).to eq(401)
            slot = slots[1]
            expect(slot['id']).to eq('3230323130353236313433303A323032313035323631353030')
            expect(slot['type']).to eq('slots')
            expect(slot['attributes']['start']).to eq('2021-05-26T14:30:00Z')
            expect(slot['attributes']['end']).to eq('2021-05-26T15:00:00Z')
          end
        end
      end

      context 'on a backend service error' do
        it 'returns a 502 status code' do
          VCR.use_cassette('vaos/v2/systems/get_available_slots_500', match_requests_on: %i[method uri]) do
            get '/vaos/v2/locations/983/clinics/570/slots?start=2021-06-01T00:00:00Z&end=2021-12-31T23:59:59Z'
            expect(response).to have_http_status(:bad_gateway)
            expect(JSON.parse(response.body)['errors'][0]['detail'])
              .to eq('Received an an invalid response from the upstream server')
          end
        end
      end
    end
  end
end
