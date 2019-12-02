# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'facilities', type: :request do
  include SchemaMatchers

  before do
    Flipper.enable('va_online_scheduling')
    sign_in_as(user)
    allow_any_instance_of(VAOS::UserService).to receive(:session).and_return('stubbed_token')
  end

  describe '/v0/vaos/facilities' do
    context 'with a loa1 user' do
      let(:user) { FactoryBot.create(:user, :loa1) }

      it 'returns a forbidden error' do
        get '/v0/vaos/facilities'
        expect(response).to have_http_status(:forbidden)
        expect(JSON.parse(response.body)['errors'].first['detail'])
          .to eq('You do not have access to online scheduling')
      end
    end

    context 'with a loa3 user' do
      let(:user) { build(:user, :mhv) }

      context 'with a valid GET facilities response' do
        it 'returns a 200 with the correct schema' do
          VCR.use_cassette('vaos/systems/get_facilities', match_requests_on: %i[method uri]) do
            get '/v0/vaos/facilities', params: { facility_code: 688 }

            expect(response).to have_http_status(:ok)
            expect(response).to match_response_schema('vaos/facilities')
          end
        end
      end

      context 'when the facility code param is missing' do
        let(:json) { JSON.parse(response.body) }

        it 'returns a 400 with missing param info' do
          VCR.use_cassette('vaos/systems/get_facilities', match_requests_on: %i[method uri]) do
            get '/v0/vaos/facilities'

            expect(response).to have_http_status(:bad_request)
            expect(json['errors'].first['detail']).to eq('The required parameter "facility_code", is missing')
          end
        end
      end
    end
  end

  describe '/v0/vaos/facility/:id/clinics' do
    context 'with a loa1 user' do
      let(:user) { FactoryBot.create(:user, :loa1) }

      it 'returns a forbidden error' do
        get '/v0/vaos/facilities/984/clinics', params: { type_of_care_id: '323', system_id: '984GA' }
        expect(response).to have_http_status(:forbidden)
        expect(JSON.parse(response.body)['errors'].first['detail'])
          .to eq('You do not have access to online scheduling')
      end
    end

    context 'with a loa3 user' do
      let(:user) { build(:user, :mhv) }

      context 'with a valid GET response' do
        it 'returns a 200 with the correct schema' do
          VCR.use_cassette('vaos/systems/get_facility_clinics', match_requests_on: %i[method uri]) do
            get '/v0/vaos/facilities/983/clinics', params: { type_of_care_id: '323', system_id: '983' }

            expect(response).to have_http_status(:ok)
            expect(response).to match_response_schema('vaos/facility_clinics')
          end
        end
      end

      context 'when a param is missing' do
        let(:json) { JSON.parse(response.body) }

        it 'returns a 400 with missing param type_of_care_id' do
          VCR.use_cassette('vaos/systems/get_facility_clinics', match_requests_on: %i[method uri]) do
            get '/v0/vaos/facilities/984/clinics', params: { system_id: '984GA' }

            expect(response).to have_http_status(:bad_request)
            expect(json['errors'].first['detail']).to eq('The required parameter "type_of_care_id", is missing')
          end
        end

        it 'returns a 400 with missing param system_id' do
          VCR.use_cassette('vaos/systems/get_facility_clinics', match_requests_on: %i[method uri]) do
            get '/v0/vaos/facilities/984/clinics', params: { type_of_care_id: '323' }

            expect(response).to have_http_status(:bad_request)
            expect(json['errors'].first['detail']).to eq('The required parameter "system_id", is missing')
          end
        end
      end
    end
  end

  describe '/v0/vaos/facilities/:id/cancel_reasons' do
    context 'with a loa1 user' do
      let(:user) { FactoryBot.create(:user, :loa1) }

      it 'returns a forbidden error' do
        get '/v0/vaos/facilities/984/cancel_reasons'
        expect(response).to have_http_status(:forbidden)
        expect(JSON.parse(response.body)['errors'].first['detail'])
          .to eq('You do not have access to online scheduling')
      end
    end

    context 'with a loa3 user' do
      let(:user) { build(:user, :mhv) }

      context 'with a valid GET response' do
        it 'returns a 200 with the correct schema' do
          VCR.use_cassette('vaos/systems/get_cancel_reasons', match_requests_on: %i[method uri]) do
            get '/v0/vaos/facilities/984/cancel_reasons'

            expect(response).to have_http_status(:ok)
            expect(response).to match_response_schema('vaos/facility_cancel_reasons')
          end
        end
      end
    end
  end
end
