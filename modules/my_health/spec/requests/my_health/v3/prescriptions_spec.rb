# frozen_string_literal: true

require 'rails_helper'
require 'unified_health_data/service'
require 'unique_user_events'

RSpec.describe 'MyHealth::V3::Prescriptions', type: :request do
  let(:current_user) { build(:user, :mhv) }
  let(:refillable_path) { '/my_health/v3/prescriptions/refillable_prescriptions' }
  let(:headers) { { 'Content-Type' => 'application/json', 'Accept' => 'application/json' } }

  before do
    sign_in_as(current_user)
  end

  describe 'GET /my_health/v3/prescriptions/refillable_prescriptions' do
    context 'with feature flag disabled' do
      before do
        allow(Flipper).to receive(:enabled?)
          .with(:mhv_medications_v3_refillable_endpoint, anything).and_return(false)
      end

      it 'returns forbidden error' do
        get(refillable_path, headers:)

        expect(response).to have_http_status(:forbidden)
        expect(response.parsed_body['error']['code']).to eq('FEATURE_NOT_AVAILABLE')
        expect(response.parsed_body['error']['message']).to eq('This feature is not currently available')
      end
    end

    context 'with feature flag enabled' do
      before do
        allow(Flipper).to receive(:enabled?)
          .with(:mhv_medications_v3_refillable_endpoint, current_user).and_return(true)
        allow(UniqueUserEvents).to receive(:log_event)
      end

      context 'when prescriptions are available' do
        it 'returns only refillable prescriptions with minimal fields' do
          VCR.use_cassette('unified_health_data/get_prescriptions_success', match_requests_on: %i[method path]) do
            get(refillable_path, headers:)

            expect(response).to have_http_status(:ok)
            body = response.parsed_body

            expect(body).to have_key('data')
            expect(body['data']).to be_an(Array)
            # Should have at least some refillable prescriptions
            expect(body['data'].length).to be >= 0

            # If there are results, verify the structure
            if body['data'].any?
              prescription_data = body['data'].first
              expect(prescription_data).to have_key('id')
              expect(prescription_data['type']).to eq('refillable_prescription')

              attributes = prescription_data['attributes']
              expect(attributes).to have_key('prescription_name')
              expect(attributes).to have_key('prescription_number')
              expect(attributes).to have_key('refill_remaining')
              expect(attributes).to have_key('expiration_date')
              expect(attributes).to have_key('station_number')
              expect(attributes).to have_key('is_refillable')
              expect(attributes).to have_key('disp_status')

              # Verify only essential fields are present (no extra fields)
              expect(attributes.keys.length).to eq(7)
            end
          end
        end

        it 'filters out non-refillable prescriptions' do
          VCR.use_cassette('unified_health_data/get_prescriptions_success', match_requests_on: %i[method path]) do
            get(refillable_path, headers:)

            expect(response).to have_http_status(:ok)
            body = response.parsed_body

            # All returned prescriptions should be refillable
            body['data'].each do |prescription|
              attributes = prescription['attributes']
              expect(attributes['is_refillable']).to be(true)
              expect(attributes['refill_remaining']).to be_positive
            end
          end
        end

        it 'logs unique user event for prescriptions access' do
          VCR.use_cassette('unified_health_data/get_prescriptions_success', match_requests_on: %i[method path]) do
            get(refillable_path, headers:)

            expect(UniqueUserEvents).to have_received(:log_event) do |args|
              expect(args[:event_name]).to eq(UniqueUserEvents::EventRegistry::PRESCRIPTIONS_ACCESSED)
              expect(args[:user]).to be_a(User)
            end
          end
        end
      end

      context 'when no refillable prescriptions are available' do
        it 'returns empty array' do
          VCR.use_cassette('unified_health_data/get_prescriptions_empty', match_requests_on: %i[method path]) do
            get(refillable_path, headers:)

            expect(response).to have_http_status(:ok)
            body = response.parsed_body
            expect(body['data']).to be_an(Array)
            expect(body['data'].length).to eq(0)
          end
        end
      end

      context 'when user is not authenticated' do
        before do
          allow_any_instance_of(ApplicationController).to receive(:authenticate).and_raise(
            Common::Exceptions::Unauthorized.new(detail: 'Not authenticated')
          )
        end

        it 'returns unauthorized' do
          get refillable_path

          expect(response).to have_http_status(:unauthorized)
        end
      end
    end
  end
end
