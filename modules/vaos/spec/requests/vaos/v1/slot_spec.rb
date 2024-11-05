# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'VAOS::V1::Slot', skip: 'deprecated', type: :request do
  before do
    Flipper.enable('va_online_scheduling')
    sign_in_as(user)
    allow_any_instance_of(VAOS::UserService).to receive(:session).and_return('stubbed_token')
  end

  describe 'GET /vaos/v1/Slot' do
    context 'with a loa1 user' do
      let(:user) { FactoryBot.create(:user, :loa1) }

      it 'returns a forbidden error' do
        get '/vaos/v1/Slot'
        expect(response).to have_http_status(:forbidden)
        error_object = JSON.parse(response.body)
        expect(error_object['resourceType']).to eq('Slot')
        expect(error_object['issue'].first['details']['text'])
          .to eq('You do not have access to online scheduling')
      end
    end

    context 'with a loa3 user' do
      let(:user) { FactoryBot.create(:user, :vaos) }

      it 'returns no slots' do
        VCR.use_cassette('vaos/fhir/slot/search_200_no_slots_found', match_requests_on: %i[method path query]) do
          get '/vaos/v1/Slot?schedule=no-such-resource'
          expect(response).to have_http_status(:ok)
          expect(JSON.parse(response.body)['total']).to eq(0)
        end
      end

      it 'returns slots' do
        VCR.use_cassette('vaos/fhir/slot/search_200_slots_found', match_requests_on: %i[method path query]) do
          get '/vaos/v1/Slot?schedule=Schedule/sch.nep.AVT987.20191208'
          expect(response).to have_http_status(:ok)
          expect(JSON.parse(response.body)['total']).to eq(2)
          expect(JSON.parse(response.body)['entry'][0]['resource']['start']).to eq('2019-12-08T09:15:00Z')
          expect(JSON.parse(response.body)['entry'][1]['resource']['start']).to eq('2019-12-08T09:15:00Z')
        end
      end

      it 'returns a 500 error' do
        VCR.use_cassette('vaos/fhir/slot/search_500', match_requests_on: %i[method path query]) do
          get '/vaos/v1/Slot?start=2020-12-08'
          expect(response).to have_http_status(:bad_gateway)
          expect(JSON.parse(response.body)['issue'].first['code']).to eq('VAOS_502')
        end
      end
    end
  end
end
