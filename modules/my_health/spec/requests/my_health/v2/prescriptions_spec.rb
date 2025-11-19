# frozen_string_literal: true

require 'rails_helper'
require 'unified_health_data/service'
require 'unique_user_events'

RSpec.describe 'MyHealth::V2::PrescriptionsController', type: :request do
  let(:user_id) { '11898795' }
  let(:current_user) { build(:user, :mhv) }
  let(:path) { '/my_health/v2/prescriptions/refill' }

  before do
    sign_in_as(current_user)
    allow(Flipper).to receive(:enabled?).with(:mhv_medications_cerner_pilot, current_user).and_return(true)
  end

  describe 'POST /my_health/v2/prescriptions/refill' do
    context 'when user is not authenticated' do
      before do
        # Override the default sign_in_as behavior for this context
        allow_any_instance_of(ApplicationController).to receive(:authenticate).and_raise(
          Common::Exceptions::Unauthorized.new(detail: 'Not authenticated')
        )
      end

      it 'returns unauthorized' do
        post path,
             params: [{ stationNumber: '123', id: '25804851' }].to_json,
             headers: { 'Content-Type' => 'application/json' }

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with feature flag disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:mhv_medications_cerner_pilot, anything).and_return(false)
      end

      it 'returns forbidden error' do
        post path,
             params: [{ stationNumber: '123', id: '25804851' }].to_json,
             headers: { 'Content-Type' => 'application/json' }

        expect(response).to have_http_status(:forbidden)
        expect(response.parsed_body['error']['code']).to eq('FEATURE_NOT_AVAILABLE')
        expect(response.parsed_body['error']['message']).to eq('This feature is not currently available')
      end
    end

    context 'with feature flag enabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:mhv_medications_cerner_pilot, current_user).and_return(true)
      end

      context 'when refill is successful' do
        it 'returns success response for batch refill' do
          allow(UniqueUserEvents).to receive(:log_event)
          VCR.use_cassette('unified_health_data/refill_prescription_success') do
            post path,
                 params: [
                   { stationNumber: '556', id: '15220389459' },
                   { stationNumber: '570', id: '0000000000001' }
                 ].to_json,
                 headers: { 'Content-Type' => 'application/json' }

            expect(response).to have_http_status(:ok)
            expect(response.parsed_body).to have_key('data')

            data = response.parsed_body['data']
            expect(data).to have_key('id')
            expect(data['type']).to eq('PrescriptionRefills')
            expect(data['attributes']).to have_key('failed_station_list')
            expect(data['attributes']).to have_key('successful_station_list')
            expect(data['attributes']).to have_key('last_updated_time')
            expect(data['attributes']).to have_key('prescription_list')
            expect(data['attributes']).to have_key('failed_prescription_ids')
            expect(data['attributes']).to have_key('errors')
            expect(data['attributes']).to have_key('info_messages')

            # Verify event logging was called
            expect(UniqueUserEvents).to have_received(:log_event).with(
              user: anything,
              event_name: UniqueUserEvents::EventRegistry::PRESCRIPTIONS_REFILL_REQUESTED
            )
          end
        end
      end

      context 'when prescription refill fails' do
        it 'returns 502 error for upstream service failure' do
          VCR.use_cassette('unified_health_data/refill_prescription_failure') do
            post path,
                 params: [{ stationNumber: '123', id: '99999999999999' }].to_json,
                 headers: { 'Content-Type' => 'application/json' }

            expect(response).to have_http_status(:bad_request)
            expect(response.parsed_body['errors'][0]['code']).to eq('VA900')
            expect(response.parsed_body['errors'][0]['detail']).to include('Operation failed')
          end
        end
      end

      context 'with invalid request format' do
        it 'returns error when orders is not an array' do
          post path,
               params: { stationNumber: '123', id: '25804851' }.to_json,
               headers: { 'Content-Type' => 'application/json' }

          expect(response).to have_http_status(:bad_request)
          error = response.parsed_body['errors']&.first
          expect(error).to be_present
          expect(error['title']).to eq('Invalid field value')
          expect(error['detail']).to include('orders')
          expect(error['detail']).to include('Must be an array')
        end

        it 'returns error when orders array is empty' do
          post path,
               params: '[]',
               headers: { 'Content-Type' => 'application/json' }

          expect(response).to have_http_status(:bad_request)
          error = response.parsed_body['errors']&.first
          expect(error).to be_present
          expect(error['title']).to eq('Missing parameter')
          expect(error['status']).to eq('400')
          expect(error['detail']).to include('orders')
        end

        it 'returns error when order is missing stationNumber' do
          post path,
               params: [{ id: '25804851' }].to_json,
               headers: { 'Content-Type' => 'application/json' }

          expect(response).to have_http_status(:bad_request)
          error = response.parsed_body['errors']&.first
          expect(error).to be_present
          expect(error['title']).to eq('Invalid field value')
          expect(error['detail']).to include('orders[0]')
          expect(error['detail']).to include('stationNumber')
        end

        it 'returns error when order is missing id' do
          post path,
               params: [{ stationNumber: '123' }].to_json,
               headers: { 'Content-Type' => 'application/json' }

          expect(response).to have_http_status(:bad_request)
          error = response.parsed_body['errors']&.first
          expect(error).to be_present
          expect(error['title']).to eq('Invalid field value')
          expect(error['detail']).to include('orders[0]')
          expect(error['detail']).to include('id')
        end

        it 'returns error when JSON is malformed' do
          post path,
               params: 'not valid json',
               headers: { 'Content-Type' => 'application/json' }

          expect(response).to have_http_status(:bad_request)
          error = response.parsed_body['errors']&.first
          expect(error).to be_present
          expect(error['title']).to eq('Invalid field value')
          expect(error['detail']).to include('orders')
          expect(error['detail']).to include('Invalid JSON format')
        end
      end

      context 'when response count does not match request count' do
        it 'returns an error for each order id when response count does not match request count' do
          VCR.use_cassette('unified_health_data/refill_prescription_success') do
            post path,
                 params: [
                   { stationNumber: '123', id: '25804851' },
                   { stationNumber: '124', id: '25804852' },
                   { stationNumber: '125', id: '25804853' }
                 ].to_json,
                 headers: { 'Content-Type' => 'application/json' }
          end

          expect(response).to have_http_status(:ok)
          expect(response.parsed_body['data']['attributes']['failed_prescription_ids'].length).to eq(3)
        end
      end
    end
  end
end
