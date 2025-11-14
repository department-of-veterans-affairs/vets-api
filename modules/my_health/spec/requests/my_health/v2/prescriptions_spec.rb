# frozen_string_literal: true

require 'rails_helper'
require 'unique_user_events'

RSpec.describe 'MyHealth::V2::Prescriptions', type: :request do
  let(:user) { build(:user, :mhv) }
  let(:headers) { { 'Content-Type' => 'application/json', 'Accept' => 'application/json' } }

  before do
    sign_in_as(user)
  end

  describe 'GET /my_health/v2/prescriptions' do
    context 'when feature flag is disabled' do
      it 'returns forbidden' do
        allow(Flipper).to receive(:enabled?).and_return(false)

        get('/my_health/v2/prescriptions', headers:)

        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when feature flag is enabled' do
      before do
        allow(Flipper).to receive(:enabled?).and_return(true)
      end

      it 'returns a successful response' do
        VCR.use_cassette('unified_health_data/get_prescriptions_success', match_requests_on: %i[method path]) do
          get('/my_health/v2/prescriptions', headers:)

          expect(response).to have_http_status(:success)
          expect(response.body).to be_a(String)
          expect(response.content_type).to include('application/json')
        end
      end

      it 'returns prescription data' do
        VCR.use_cassette('unified_health_data/get_prescriptions_success', match_requests_on: %i[method path]) do
          get('/my_health/v2/prescriptions', headers:)

          json_response = JSON.parse(response.body)
          expect(json_response['data']).to be_an(Array)
          expect(json_response['data'].length).to be_positive
        end
      end

      it 'includes expected attributes' do
        VCR.use_cassette('unified_health_data/get_prescriptions_success', match_requests_on: %i[method path]) do
          get('/my_health/v2/prescriptions', headers:)

          json_response = JSON.parse(response.body)
          prescription = json_response['data'].first
          attributes = prescription['attributes']

          expect(attributes).to include(
            'prescription_id',
            'prescription_number',
            'prescription_name',
            'refill_status'
          )
        end
      end

      it 'includes metadata' do
        VCR.use_cassette('unified_health_data/get_prescriptions_success', match_requests_on: %i[method path]) do
          get('/my_health/v2/prescriptions', headers:)

          json_response = JSON.parse(response.body)
          expect(json_response['meta']).to have_key('filter_count')
          expect(json_response['meta']).to have_key('recently_requested')

          # Verify filter_count includes all expected fields
          filter_count = json_response['meta']['filter_count']
          expect(filter_count).to include(
            'all_medications', 'active', 'recently_requested', 'renewal', 'non_active'
          )
          expect(filter_count['all_medications']).to be >= 0
          expect(filter_count['active']).to be >= 0
          expect(filter_count['recently_requested']).to be >= 0
          expect(filter_count['renewal']).to be >= 0
          expect(filter_count['non_active']).to be >= 0
        end
      end

      it 'includes Oracle/UHD data' do
        VCR.use_cassette('unified_health_data/get_prescriptions_success', match_requests_on: %i[method path]) do
          get('/my_health/v2/prescriptions', headers:)

          json_response = JSON.parse(response.body)
          expect(json_response['data']).to be_an(Array)
          expect(json_response['data']).not_to be_empty

          # Find an RX prescription (Oracle data) - not PD (pending)
          rx_prescription = json_response['data'].find do |rx|
            rx['attributes']['prescription_source'] == 'RX'
          end
          expect(rx_prescription).not_to be_nil, 'Expected to find at least one RX prescription in response'

          attributes = rx_prescription['attributes']

          # These are Oracle/UHD specific fields that come from the unified_health_data service
          expect(attributes).to have_key('facility_name')
          expect(attributes).to have_key('station_number')
          expect(attributes).to have_key('is_refillable')
          expect(attributes).to have_key('is_trackable')
          expect(attributes).to have_key('prescription_source')

          # Verify the prescription_source indicates this is from Oracle
          expect(attributes['prescription_source']).to eq('RX')
        end
      end

      it 'groups prescription renewals together' do
        VCR.use_cassette('unified_health_data/get_prescriptions_success', match_requests_on: %i[method path]) do
          get('/my_health/v2/prescriptions', headers:)

          json_response = JSON.parse(response.body)
          prescriptions = json_response['data']

          # Find prescription 2721391 which should have grouped renewals (RX base + RF1)
          base_prescription = prescriptions.find do |rx|
            rx['attributes']['prescription_number'] == '2721391' &&
              rx['attributes']['prescription_source'] == 'RX'
          end

          expect(base_prescription).not_to be_nil,
                                           'Expected to find prescription 2721391 with RX source as base'

          # Verify it has grouped_medications
          grouped_meds = base_prescription['attributes']['grouped_medications']
          expect(grouped_meds).to be_present,
                                  'Expected prescription 2721391 (RX) to have grouped_medications'
          expect(grouped_meds).to be_an(Array)
          expect(grouped_meds.length).to eq(1),
                                         'Expected prescription 2721391 to have 1 renewal (RF1)'

          # Verify the grouped medication details
          renewal = grouped_meds.first
          expect(renewal['prescription_number']).to eq('2721391')
          expect(renewal['prescription_source']).to eq('RF')

          # Verify that the RF1 renewal is NOT in the main list as a separate entry
          rf_in_main_list = prescriptions.find do |rx|
            rx['attributes']['prescription_number'] == '2721391' &&
              rx['attributes']['prescription_source'] == 'RF'
          end
          expect(rf_in_main_list).to be_nil,
                                     'RF renewal should not appear separately in the main list'
        end
      end

      it 'returns camelCase when X-Key-Inflection: camel header is provided' do
        VCR.use_cassette('unified_health_data/get_prescriptions_success', match_requests_on: %i[method path]) do
          camel_headers = headers.merge('X-Key-Inflection' => 'camel')
          get '/my_health/v2/prescriptions', headers: camel_headers

          json_response = JSON.parse(response.body)

          # Verify meta keys are camelCase
          expect(json_response['meta']).to have_key('filterCount')
          expect(json_response['meta']).to have_key('recentlyRequested')
          expect(json_response['meta']).not_to have_key('filter_count')
          expect(json_response['meta']).not_to have_key('recently_requested')

          # Verify attribute keys are camelCase
          prescription = json_response['data'].first
          attributes = prescription['attributes']
          expect(attributes).to have_key('prescriptionId')
          expect(attributes).to have_key('prescriptionNumber')
          expect(attributes).to have_key('prescriptionName')
          expect(attributes).to have_key('refillStatus')
          expect(attributes).not_to have_key('prescription_id')
          expect(attributes).not_to have_key('prescription_number')
        end
      end

      it 'accepts include_image parameter without error' do
        VCR.use_cassette('unified_health_data/get_prescriptions_success', match_requests_on: %i[method path]) do
          # UHD prescriptions don't have cmop_ndc_value so images won't be fetched,
          # but the parameter should be accepted and not cause errors
          get('/my_health/v2/prescriptions', params: { include_image: true }, headers:)

          expect(response).to have_http_status(:success)
          json_response = JSON.parse(response.body)
          expect(json_response['data']).to be_an(Array)
          expect(json_response['data']).not_to be_empty
        end
      end

      context 'when mhv_medications_display_pending_meds flipper is enabled' do
        before do
          # Override the parent context's generic stub - be specific about feature flags
          allow(Flipper).to receive(:enabled?).and_call_original
          allow(Flipper).to receive(:enabled?).with(:mhv_medications_cerner_pilot, anything).and_return(true)
          allow(Flipper).to receive(:enabled?).with(:mhv_medications_display_pending_meds, anything).and_return(true)
        end

        it 'includes PD (pending) prescriptions in the response' do
          VCR.use_cassette('unified_health_data/get_prescriptions_success', match_requests_on: %i[method path]) do
            get('/my_health/v2/prescriptions', headers:)

            json_response = JSON.parse(response.body)

            # Find PD prescriptions
            pd_prescriptions = json_response['data'].select do |rx|
              rx['attributes']['prescription_source'] == 'PD'
            end

            expect(pd_prescriptions).not_to be_empty, 'Expected to find PD prescriptions when flipper is enabled'
          end
        end
      end

      context 'when mhv_medications_display_pending_meds flipper is disabled' do
        before do
          # Override the parent context's generic stub - be specific about feature flags
          allow(Flipper).to receive(:enabled?).and_call_original
          allow(Flipper).to receive(:enabled?).with(:mhv_medications_cerner_pilot, anything).and_return(true)
          allow(Flipper).to receive(:enabled?).with(:mhv_medications_display_pending_meds, anything).and_return(false)
        end

        it 'excludes PD (pending) prescriptions from the response' do
          VCR.use_cassette('unified_health_data/get_prescriptions_success', match_requests_on: %i[method path]) do
            get('/my_health/v2/prescriptions', headers:)

            json_response = JSON.parse(response.body)

            # Verify no PD prescriptions are present
            pd_prescriptions = json_response['data'].select do |rx|
              rx['attributes']['prescription_source'] == 'PD'
            end

            expect(pd_prescriptions).to be_empty, 'Expected no PD prescriptions when flipper is disabled'
          end
        end
      end

      it 'includes pagination metadata' do
        VCR.use_cassette('unified_health_data/get_prescriptions_success', match_requests_on: %i[method path]) do
          get('/my_health/v2/prescriptions', params: { page: 1, per_page: 5 }, headers:)

          json_response = JSON.parse(response.body)
          expect(response).to have_http_status(:success)

          # Verify pagination metadata
          expect(json_response['meta']).to have_key('pagination')
          pagination = json_response['meta']['pagination']
          expect(pagination['current_page']).to eq(1)
          expect(pagination['per_page']).to eq(5)
          expect(pagination).to have_key('total_pages')
          expect(pagination).to have_key('total_entries')

          # Verify pagination links (all five standard pagination links)
          expect(json_response['links']).to have_key('self')
          expect(json_response['links']).to have_key('first')
          expect(json_response['links']).to have_key('last')
          expect(json_response['links']).to have_key('prev')
          expect(json_response['links']).to have_key('next')

          # Verify data length respects per_page limit
          expect(json_response['data'].length).to be <= 5
        end
      end

      it 'sorts prescriptions alphabetically by name' do
        VCR.use_cassette('unified_health_data/get_prescriptions_success', match_requests_on: %i[method path]) do
          get('/my_health/v2/prescriptions', params: { sort: 'alphabetical-rx-name' }, headers:)

          json_response = JSON.parse(response.body)
          expect(response).to have_http_status(:success)

          # Get non-PD prescription data
          prescriptions = json_response['data']
                          .reject { |rx| rx['attributes']['prescription_source'] == 'PD' }

          prescription_names = prescriptions.map { |rx| rx['attributes']['prescription_name'] }

          # Verify they are sorted alphabetically (case-insensitive)
          expect(prescription_names).to eq(prescription_names.sort)

          # If prescriptions have the same name, verify secondary sort by dispensed_date (newest first)
          prescriptions.group_by { |rx| rx['attributes']['prescription_name'] }.each_value do |meds|
            next if meds.length < 2

            dispensed_dates = meds.map do |m|
              m['attributes']['sorted_dispensed_date'] || m['attributes']['dispensed_date']
            end.compact

            # Verify dates are in descending order (newest first)
            expect(dispensed_dates).to eq(dispensed_dates.sort.reverse) if dispensed_dates.length > 1
          end
        end
      end

      it 'accepts last-fill-date sort parameter' do
        VCR.use_cassette('unified_health_data/get_prescriptions_success', match_requests_on: %i[method path]) do
          get('/my_health/v2/prescriptions', params: { sort: 'last-fill-date' }, headers:)

          json_response = JSON.parse(response.body)
          expect(response).to have_http_status(:success)
          expect(json_response['data']).to be_an(Array)
          expect(json_response['data']).not_to be_empty

          # Verify prescriptions have dispensed_date field
          prescription_with_date = json_response['data'].find { |rx| rx['attributes']['dispensed_date'].present? }
          expect(prescription_with_date).not_to be_nil
        end
      end

      it 'uses default sort order when no sort parameter provided' do
        VCR.use_cassette('unified_health_data/get_prescriptions_success', match_requests_on: %i[method path]) do
          get('/my_health/v2/prescriptions', headers:)

          json_response = JSON.parse(response.body)
          expect(response).to have_http_status(:success)

          # Default sort is by disp_status ASC, then prescription_name ASC
          # Skip PD prescriptions in verification
          prescriptions = json_response['data'].reject { |rx| rx['attributes']['prescription_source'] == 'PD' }

          # Verify that prescriptions are grouped by disp_status and within each group sorted by name
          prev_status = nil
          prev_name = nil

          prescriptions.each do |rx|
            attrs = rx['attributes']
            status = attrs['disp_status'] || ''
            name = attrs['prescription_name'] || ''

            if prev_status && prev_status == status && prev_name
              # Within same status, names should be ascending
              expect(name).to be >= prev_name
            end

            prev_status = status
            prev_name = name
          end
        end
      end

      it 'accepts disp_status filter parameter' do
        VCR.use_cassette('unified_health_data/get_prescriptions_success', match_requests_on: %i[method path]) do
          # Test with Active filter - use query string format
          get('/my_health/v2/prescriptions?filter[[disp_status][eq]]=Active', headers:)

          json_response = JSON.parse(response.body)
          expect(response).to have_http_status(:success)
          expect(json_response['data']).to be_an(Array)

          # Verify filter_count metadata exists and contains expected fields
          expect(json_response['meta']).to have_key('filter_count')
          expect(json_response['meta']['filter_count']).to include(
            'all_medications', 'active', 'recently_requested', 'renewal', 'non_active'
          )

          # Verify all returned prescriptions match the filter (Active)
          disp_statuses = json_response['data'].map { |rx| rx['attributes']['disp_status'] }.compact
          expect(disp_statuses).to all(eq('Active')) if disp_statuses.any?
        end
      end

      it 'filters and paginates prescriptions' do
        VCR.use_cassette('unified_health_data/get_prescriptions_success', match_requests_on: %i[method path]) do
          get('/my_health/v2/prescriptions?filter[[disp_status][eq]]=Active&page=1&per_page=2', headers:)

          json_response = JSON.parse(response.body)
          expect(response).to have_http_status(:success)
          expect(json_response['data'].length).to be <= 2

          # Verify pagination metadata is present when using both filter and pagination
          expect(json_response['meta']).to have_key('pagination')
          expect(json_response['meta']['pagination']['per_page']).to eq(2)
        end
      end

      it 'filters prescriptions with multiple disp_status values' do
        VCR.use_cassette('unified_health_data/get_prescriptions_success', match_requests_on: %i[method path]) do
          get('/my_health/v2/prescriptions?filter[[disp_status][eq]]=Active,Expired', headers:)

          json_response = JSON.parse(response.body)
          expect(response).to have_http_status(:success)

          # Verify filter_count metadata
          expect(json_response['meta']).to have_key('filter_count')

          # Verify all returned prescriptions have disp_status of Active or Expired
          disp_statuses = json_response['data'].map { |rx| rx['attributes']['disp_status'] }.compact
          expect(disp_statuses).to all(be_in(%w[Active Expired])) if disp_statuses.any?
        end
      end

      it 'logs prescription access via UniqueUserEvents' do
        VCR.use_cassette('unified_health_data/get_prescriptions_success', match_requests_on: %i[method path]) do
          # Mock UniqueUserEvents to verify log_event is called
          allow(UniqueUserEvents).to receive(:log_event)

          get('/my_health/v2/prescriptions', headers:)

          expect(response).to have_http_status(:success)

          # Verify event logging was called
          expect(UniqueUserEvents).to have_received(:log_event).with(
            user: anything,
            event_name: 'mhv_rx_accessed'
          )
        end
      end

      it 'includes recently_requested prescriptions in metadata' do
        VCR.use_cassette('unified_health_data/get_prescriptions_success', match_requests_on: %i[method path]) do
          get('/my_health/v2/prescriptions', headers:)

          json_response = JSON.parse(response.body)
          expect(json_response['meta']).to have_key('recently_requested')

          recently_requested = json_response['meta']['recently_requested']
          expect(recently_requested).to be_an(Array)

          # Verify recently_requested contains prescriptions with specific disp_status values
          # These should be prescriptions with 'Active: Refill in Process' or 'Active: Submitted'
          recently_requested.each do |rx|
            status = rx['disp_status']
            expect(status).to be_in(['Active: Refill in Process', 'Active: Submitted']) if status.present?
          end
        end
      end

      it 'sorts PD prescriptions to the top when pending meds enabled' do
        VCR.use_cassette('unified_health_data/get_prescriptions_success', match_requests_on: %i[method path]) do
          # Enable pending meds flipper
          allow(Flipper).to receive(:enabled?).and_call_original
          allow(Flipper).to receive(:enabled?).with(:mhv_medications_cerner_pilot, anything).and_return(true)
          allow(Flipper).to receive(:enabled?).with(:mhv_medications_display_pending_meds, anything).and_return(true)

          get('/my_health/v2/prescriptions', headers:)

          json_response = JSON.parse(response.body)
          expect(response).to have_http_status(:success)

          # Find indices of PD and non-PD prescriptions
          pd_indices = []
          non_pd_indices = []

          json_response['data'].each_with_index do |rx, index|
            if rx['attributes']['prescription_source'] == 'PD'
              pd_indices << index
            else
              non_pd_indices << index
            end
          end

          # All PD prescriptions should come before all non-PD prescriptions
          if pd_indices.any? && non_pd_indices.any?
            expect(pd_indices.max).to be < non_pd_indices.min,
                                      'PD prescriptions should appear before non-PD prescriptions'
          end
        end
      end
    end
  end

  describe 'POST /my_health/v2/prescriptions/refill' do
    context 'when feature flag is enabled' do
      before do
        allow(Flipper).to receive(:enabled?).and_return(true)
      end

      it 'refills prescriptions and logs event' do
        VCR.use_cassette('unified_health_data/refill_prescriptions_success', match_requests_on: %i[method path]) do
          allow(UniqueUserEvents).to receive(:log_event)

          orders = [
            { stationNumber: '989', id: '3636691' }
          ]

          post('/my_health/v2/prescriptions/refill',
               params: orders.to_json,
               headers:)

          expect(response).to have_http_status(:success)
          expect(response.body).to be_a(String)

          # Verify event logging was called
          expect(UniqueUserEvents).to have_received(:log_event).with(
            user: anything,
            event_name: UniqueUserEvents::EventRegistry::PRESCRIPTIONS_REFILL_REQUESTED
          )
        end
      end

      it 'validates required fields in orders' do
        allow(UniqueUserEvents).to receive(:log_event)

        # Missing required fields
        invalid_orders = [
          { stationNumber: '989' } # missing id
        ]

        post('/my_health/v2/prescriptions/refill',
             params: invalid_orders.to_json,
             headers:)

        expect(response).to have_http_status(:bad_request)
      end

      it 'requires orders to be an array' do
        allow(UniqueUserEvents).to receive(:log_event)

        # Not an array
        invalid_params = { stationNumber: '989', id: '3636691' }

        post('/my_health/v2/prescriptions/refill',
             params: invalid_params.to_json,
             headers:)

        expect(response).to have_http_status(:bad_request)
      end

      it 'requires at least one order' do
        allow(UniqueUserEvents).to receive(:log_event)

        # Empty array
        empty_orders = []

        post('/my_health/v2/prescriptions/refill',
             params: empty_orders.to_json,
             headers:)

        expect(response).to have_http_status(:bad_request)
      end
    end

    context 'when feature flag is disabled' do
      it 'returns forbidden' do
        allow(Flipper).to receive(:enabled?).and_return(false)

        orders = [
          { stationNumber: '989', id: '3636691' }
        ]

        post('/my_health/v2/prescriptions/refill',
             params: orders.to_json,
             headers:)

        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
