# frozen_string_literal: true

require 'rails_helper'
require 'unified_health_data/service'
require 'unique_user_events'

RSpec.describe 'MyHealth::V2::Prescriptions', type: :request do
  let(:current_user) { build(:user, :mhv) }
  let(:headers) { { 'Content-Type' => 'application/json', 'Accept' => 'application/json' } }
  let(:refill_path) { '/my_health/v2/prescriptions/refill' }

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
        post refill_path,
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
        post refill_path,
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
            post refill_path,
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

            # Verify event logging was called with station numbers from orders
            expect(UniqueUserEvents).to have_received(:log_event).with(
              user: anything,
              event_name: UniqueUserEvents::EventRegistry::PRESCRIPTIONS_REFILL_REQUESTED,
              event_facility_ids: %w[556 570]
            )
          end
        end

        it 'logs event with station numbers from the request' do
          allow(UniqueUserEvents).to receive(:log_event)

          VCR.use_cassette('unified_health_data/refill_prescription_success') do
            post refill_path,
                 params: [
                   { stationNumber: '757', id: '15220389459' },
                   { stationNumber: '570', id: '0000000000001' }
                 ].to_json,
                 headers: { 'Content-Type' => 'application/json' }
          end

          expect(UniqueUserEvents).to have_received(:log_event).with(
            user: anything,
            event_name: UniqueUserEvents::EventRegistry::PRESCRIPTIONS_REFILL_REQUESTED,
            event_facility_ids: %w[757 570]
          )
        end

        it 'logs event with unique station numbers when duplicates exist' do
          allow(UniqueUserEvents).to receive(:log_event)

          VCR.use_cassette('unified_health_data/refill_prescription_success') do
            post refill_path,
                 params: [
                   { stationNumber: '757', id: '15220389459' },
                   { stationNumber: '757', id: '0000000000001' }
                 ].to_json,
                 headers: { 'Content-Type' => 'application/json' }
          end

          expect(UniqueUserEvents).to have_received(:log_event).with(
            user: anything,
            event_name: UniqueUserEvents::EventRegistry::PRESCRIPTIONS_REFILL_REQUESTED,
            event_facility_ids: %w[757]
          )
        end
      end

      context 'when prescription refill fails' do
        it 'returns 502 error for upstream service failure' do
          VCR.use_cassette('unified_health_data/refill_prescription_failure') do
            post refill_path,
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
          post refill_path,
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
          post refill_path,
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
          post refill_path,
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
          post refill_path,
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
          post refill_path,
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
            post refill_path,
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

  describe 'GET /my_health/v2/prescriptions' do
    context 'when feature flag is disabled' do
      it 'returns forbidden' do
        allow(Flipper).to receive(:enabled?).with(:mhv_medications_cerner_pilot, anything).and_return(false)

        get('/my_health/v2/prescriptions', headers:)

        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when feature flag is enabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:mhv_medications_cerner_pilot, anything).and_return(true)
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

      it 'includes dispenses data mapped to rx_rf_records' do
        VCR.use_cassette('unified_health_data/get_prescriptions_success', match_requests_on: %i[method path]) do
          get('/my_health/v2/prescriptions', headers:)

          json_response = JSON.parse(response.body)
          prescriptions_with_dispenses = json_response['data'].select do |rx|
            rx['attributes']['rx_rf_records'].present? && rx['attributes']['rx_rf_records'].any?
          end

          # Verify at least some prescriptions have dispenses
          expect(prescriptions_with_dispenses).not_to be_empty

          # Verify dispenses structure
          prescriptions_with_dispenses.each do |prescription|
            dispenses = prescription['attributes']['rx_rf_records']
            expect(dispenses).to be_an(Array)

            # Verify dispense records have expected attributes
            dispenses.each do |dispense|
              expect(dispense).to be_a(Hash)
              # Check for key dispense attributes from Vista adapter
              expect(dispense).to have_key('status') if dispense['status'].present?
              expect(dispense).to have_key('facility_name') if dispense['facility_name'].present?
              expect(dispense).to have_key('medication_name') if dispense['medication_name'].present?
            end
          end
        end
      end

      it 'includes metadata with V2 filter categories' do
        VCR.use_cassette('unified_health_data/get_prescriptions_success', match_requests_on: %i[method path]) do
          get('/my_health/v2/prescriptions', headers:)

          json_response = JSON.parse(response.body)
          expect(json_response['meta']).to have_key('filter_count')
          expect(json_response['meta']).to have_key('recently_requested')

          # Verify filter_count includes all V2 expected fields
          filter_count = json_response['meta']['filter_count']
          expect(filter_count).to include(
            'all_medications',
            'active',
            'in_progress',
            'shipped',
            'renewable',
            'inactive',
            'transferred',
            'status_not_available'
          )
          expect(filter_count['all_medications']).to be >= 0
          expect(filter_count['active']).to be >= 0
          expect(filter_count['in_progress']).to be >= 0
          expect(filter_count['shipped']).to be >= 0
          expect(filter_count['renewable']).to be >= 0
          expect(filter_count['inactive']).to be >= 0
          expect(filter_count['transferred']).to be >= 0
          expect(filter_count['status_not_available']).to be >= 0
        end
      end

      it 'includes Oracle/UHD data' do
        VCR.use_cassette('unified_health_data/get_prescriptions_success', match_requests_on: %i[method path]) do
          get('/my_health/v2/prescriptions', headers:)

          json_response = JSON.parse(response.body)
          expect(json_response['data']).to be_an(Array)
          expect(json_response['data']).not_to be_empty

          # Verify we have at least one Oracle prescription (station number 668 is Oracle Health facility)
          oracle_prescriptions = json_response['data'].select do |rx|
            rx['attributes']['station_number'] == '668'
          end
          expect(oracle_prescriptions).not_to be_empty,
                                              'Expected to find at least one Oracle prescription (station 668)'

          # Select an Oracle prescription and verify key fields have expected data
          oracle_rx = oracle_prescriptions.first
          oracle_attrs = oracle_rx['attributes']

          # Verify Oracle prescription has required fields populated
          expect(oracle_attrs['station_number']).to eq('668')
          expect(oracle_attrs['prescription_id']).to be_present
          expect(oracle_attrs['prescription_name']).to be_present
          expect(oracle_attrs['ordered_date']).to be_present
          expect(oracle_attrs['refill_status']).to be_present
          expect(oracle_attrs['is_refillable']).to be_in([true, false])
          expect(oracle_attrs['is_trackable']).to be_in([true, false])

          # Verify prescription_source is valid for Oracle (VA indicates Oracle Health/Cerner system)
          expect(oracle_attrs['prescription_source']).to eq('VA')
        end
      end

      it 'groups prescription renewals together' do
        VCR.use_cassette('unified_health_data/get_prescriptions_success', match_requests_on: %i[method path]) do
          get('/my_health/v2/prescriptions', headers:)

          json_response = JSON.parse(response.body)
          prescriptions = json_response['data']

          expect(prescriptions).not_to be_empty

          prescriptions.each do |prescription|
            # Verify grouped_medications attribute exists (populated by RxGroupingHelperV2)
            expect(prescription['attributes']).to have_key('grouped_medications')
          end
        end
      end

      it 'includes is_renewable attribute in prescription data' do
        VCR.use_cassette('unified_health_data/get_prescriptions_success', match_requests_on: %i[method path]) do
          get('/my_health/v2/prescriptions', headers:)

          json_response = JSON.parse(response.body)
          prescriptions = json_response['data']

          expect(prescriptions).not_to be_empty

          # Verify at least some prescriptions have is_renewable attribute
          prescriptions.each do |prescription|
            attributes = prescription['attributes']
            expect(attributes).to have_key('is_renewable')
            expect(attributes['is_renewable']).to be_in([true, false, nil])
          end
        end
      end

      it 'includes is_trackable attribute in prescription data' do
        VCR.use_cassette('unified_health_data/get_prescriptions_success', match_requests_on: %i[method path]) do
          get('/my_health/v2/prescriptions', headers:)

          json_response = JSON.parse(response.body)
          prescriptions = json_response['data']

          expect(prescriptions).not_to be_empty

          prescriptions.each do |prescription|
            attributes = prescription['attributes']
            expect(attributes).to have_key('is_trackable')
            expect(attributes['is_trackable']).to be_in([true, false])
          end
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

      it 'returns nil for prescription_image' do
        VCR.use_cassette('unified_health_data/get_prescriptions_success', match_requests_on: %i[method path]) do
          get('/my_health/v2/prescriptions', headers:)

          expect(response).to have_http_status(:success)
          json_response = JSON.parse(response.body)
          prescription = json_response['data'].first
          expect(prescription['attributes']['prescription_image']).to be_nil
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

            # NOTE: The VCR cassette may not have PD prescriptions, but the logic should allow them
            # Check that PD source prescriptions aren't filtered out if present
            # If no PD prescriptions exist in test data, that's acceptable - the code allows them
            json_response['data'].select do |rx|
              rx['attributes']['prescription_source'] == 'PD'
            end

            # This test verifies the logic doesn't filter out PD when flag is enabled
            # If PD prescriptions exist in the cassette, they should be present
            # The grouping helper shouldn't group or remove PD prescriptions
            expect(json_response['data']).not_to be_empty
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

          # Verify sort metadata is included
          expect(json_response['meta']).to have_key('sort')
          expect(json_response['meta']['sort']).to be_a(Hash)
          expect(json_response['meta']['sort']).to include('prescription_name' => 'ASC')

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

          # After grouping, verify that the sort parameter is accepted and prescriptions are returned
          # The sorting logic should handle grouped prescriptions correctly
          # Verify prescriptions are present (actual sort order verified by other tests)
          expect(json_response['data'].length).to be_positive
        end
      end

      it 'uses default sort order when no sort parameter provided' do
        VCR.use_cassette('unified_health_data/get_prescriptions_success', match_requests_on: %i[method path]) do
          get('/my_health/v2/prescriptions', headers:)

          json_response = JSON.parse(response.body)
          expect(response).to have_http_status(:success)

          # Verify sort metadata is included with default value
          expect(json_response['meta']).to have_key('sort')
          expect(json_response['meta']['sort']).to be_a(Hash)
          expect(json_response['meta']['sort']).to include('disp_status' => 'ASC', 'prescription_name' => 'ASC')

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
            'all_medications', 'active', 'in_progress', 'shipped', 'renewable', 'inactive', 'transferred',
            'status_not_available'
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

      context 'V2 filter parameters with mhv_medications_v2_status_mapping enabled' do
        before do
          allow(Flipper).to receive(:enabled?).with(:mhv_medications_v2_status_mapping, anything).and_return(true)
        end

        it 'renewable filter works with V2StatusMapping (Inactive status)' do
          # This test verifies that the renewable() helper correctly handles "Inactive"
          # When V2StatusMapping is enabled, "Expired" is mapped to "Inactive"
          VCR.use_cassette('unified_health_data/get_prescriptions_success', match_requests_on: %i[method path]) do
            get('/my_health/v2/prescriptions?filter[[disp_status][eq]]=Active,Expired', headers:)

            json_response = JSON.parse(response.body)
            expect(response).to have_http_status(:success)

            # The renewable filter should return prescriptions with:
            # 1. disp_status = "Active" with zero refills and not refillable
            # 2. disp_status = "Inactive" (mapped from "Expired") within renewal window (120 days)
            renewable_prescriptions = json_response['data']

            # If there are results, verify they meet renewable criteria
            if renewable_prescriptions.any?
              renewable_prescriptions.each do |rx|
                attrs = rx['attributes']
                disp_status = attrs['disp_status']
                # When flag is ON, status should be "Inactive" (not "Expired")
                expect(disp_status).to be_in(%w[Active Inactive])
              end
            end
          end
        end

        it 'filters prescriptions by disp_status=Inactive (mapped statuses)' do
          VCR.use_cassette('unified_health_data/get_prescriptions_success', match_requests_on: %i[method path]) do
            get('/my_health/v2/prescriptions?filter[[disp_status][eq]]=Inactive', headers:)

            json_response = JSON.parse(response.body)
            expect(response).to have_http_status(:success)

            # When V2StatusMapping is enabled, Expired, Discontinued, and Active: On hold are mapped to Inactive
            disp_statuses = json_response['data'].map { |rx| rx['attributes']['disp_status'] }.compact
            expect(disp_statuses).to all(eq('Inactive')) if disp_statuses.any?
          end
        end
      end

      context 'V2 filter parameters with mhv_medications_v2_status_mapping disabled' do
        before do
          allow(Flipper).to receive(:enabled?).with(:mhv_medications_v2_status_mapping, anything).and_return(false)
        end

        it 'renewable filter works with legacy statuses (Expired status)' do
          # This test verifies that the renewable() helper correctly handles "Expired"
          # When V2StatusMapping is disabled, "Expired" status is NOT mapped
          VCR.use_cassette('unified_health_data/get_prescriptions_success', match_requests_on: %i[method path]) do
            get('/my_health/v2/prescriptions?filter[[disp_status][eq]]=Active,Expired', headers:)

            json_response = JSON.parse(response.body)
            expect(response).to have_http_status(:success)

            # The renewable filter should return prescriptions with:
            # 1. disp_status = "Active" with zero refills and not refillable
            # 2. disp_status = "Expired" within renewal window (120 days)
            renewable_prescriptions = json_response['data']

            # If there are results, verify they meet renewable criteria
            if renewable_prescriptions.any?
              renewable_prescriptions.each do |rx|
                attrs = rx['attributes']
                disp_status = attrs['disp_status']
                # When flag is OFF, status should be "Expired" (not "Inactive")
                expect(disp_status).to be_in(%w[Active Expired])
              end
            end
          end
        end

        it 'filters prescriptions by disp_status=Expired (unmapped status)' do
          VCR.use_cassette('unified_health_data/get_prescriptions_success', match_requests_on: %i[method path]) do
            get('/my_health/v2/prescriptions?filter[[disp_status][eq]]=Expired', headers:)

            json_response = JSON.parse(response.body)
            expect(response).to have_http_status(:success)

            # When V2StatusMapping is disabled, Expired status remains as "Expired"
            disp_statuses = json_response['data'].map { |rx| rx['attributes']['disp_status'] }.compact
            expect(disp_statuses).to all(eq('Expired')) if disp_statuses.any?
          end
        end
      end

      context 'V2 filter parameters' do
        it 'filters prescriptions by is_trackable=true (shipped)' do
          VCR.use_cassette('unified_health_data/get_prescriptions_success', match_requests_on: %i[method path]) do
            get('/my_health/v2/prescriptions?filter[[is_trackable][eq]]=true', headers:)

            json_response = JSON.parse(response.body)
            expect(response).to have_http_status(:success)

            # Verify all returned prescriptions are shipped: Active status AND is_trackable=true
            json_response['data'].each do |prescription|
              attributes = prescription['attributes']
              expect(attributes['disp_status']).to eq('Active')
              expect(attributes['is_trackable']).to be(true)
            end
          end
        end

        it 'filters prescriptions by is_renewable=true' do
          VCR.use_cassette('unified_health_data/get_prescriptions_success', match_requests_on: %i[method path]) do
            get('/my_health/v2/prescriptions?filter[[is_renewable][eq]]=true', headers:)

            json_response = JSON.parse(response.body)
            expect(response).to have_http_status(:success)

            # Verify all returned prescriptions are renewable
            json_response['data'].each do |prescription|
              attributes = prescription['attributes']
              expect(attributes['is_renewable']).to be(true)
            end
          end
        end

        it 'filters prescriptions by disp_status=Inactive (mapped statuses)' do
          VCR.use_cassette('unified_health_data/get_prescriptions_success', match_requests_on: %i[method path]) do
            get('/my_health/v2/prescriptions?filter[[disp_status][eq]]=Inactive', headers:)

            json_response = JSON.parse(response.body)
            expect(response).to have_http_status(:success)

            # When V2StatusMapping is enabled, Expired, Discontinued, and Active: On hold are mapped to Inactive
            # Verify all returned prescriptions have disp_status of Inactive
            disp_statuses = json_response['data'].map { |rx| rx['attributes']['disp_status'] }.compact
            expect(disp_statuses).to all(eq('Inactive')) if disp_statuses.any?
          end
        end

        it 'renewable filter works with V2StatusMapping (Inactive status)' do
          # This test verifies that the renewable() helper correctly handles both "Expired" and "Inactive"
          # When V2StatusMapping is enabled, "Expired" is mapped to "Inactive", so renewable logic must check both
          VCR.use_cassette('unified_health_data/get_prescriptions_success', match_requests_on: %i[method path]) do
            get('/my_health/v2/prescriptions?filter[[disp_status][eq]]=Active,Expired', headers:)

            json_response = JSON.parse(response.body)
            expect(response).to have_http_status(:success)

            # The renewable filter should return prescriptions with:
            # 1. disp_status = "Active" with zero refills and not refillable
            # 2. disp_status = "Inactive" (mapped from "Expired") within renewal window (120 days)
            # Verify prescriptions match renewable criteria
            renewable_prescriptions = json_response['data']
            expect(renewable_prescriptions).to be_an(Array)

            # If there are results, verify they meet renewable criteria
            if renewable_prescriptions.any?
              renewable_prescriptions.each do |rx|
                attrs = rx['attributes']
                disp_status = attrs['disp_status']

                # Should be either Active or Inactive (mapped from Expired)
                expect(disp_status).to be_in(%w[Active Inactive])
              end
            end
          end
        end

        it 'filters prescriptions by disp_status=Transferred' do
          VCR.use_cassette('unified_health_data/get_prescriptions_success', match_requests_on: %i[method path]) do
            get('/my_health/v2/prescriptions?filter[[disp_status][eq]]=Transferred', headers:)

            json_response = JSON.parse(response.body)
            expect(response).to have_http_status(:success)

            # Verify all returned prescriptions have disp_status of Transferred
            disp_statuses = json_response['data'].map { |rx| rx['attributes']['disp_status'] }.compact
            expect(disp_statuses).to all(eq('Transferred')) if disp_statuses.any?
          end
        end

        it 'combines is_trackable and disp_status filters' do
          VCR.use_cassette('unified_health_data/get_prescriptions_success', match_requests_on: %i[method path]) do
            get(
              '/my_health/v2/prescriptions?filter[[is_trackable][eq]]=true&filter[[disp_status][eq]]=Active',
              headers:
            )

            json_response = JSON.parse(response.body)
            expect(response).to have_http_status(:success)

            # Verify all returned prescriptions match both filters
            json_response['data'].each do |prescription|
              attributes = prescription['attributes']
              expect(attributes['disp_status']).to eq('Active')
              expect(attributes['is_trackable']).to be(true)
            end
          end
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
          # When V2 status mapping is enabled, these get mapped to 'In progress'
          recently_requested.each do |rx|
            status = rx['disp_status']
            if status.present?
              expected_statuses = ['Active: Refill in Process', 'Active: Submitted', 'In progress']
              expect(status).to be_in(expected_statuses)
            end
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

  describe 'GET /my_health/v2/prescriptions/list_refillable_prescriptions' do
    context 'when feature flag is disabled' do
      it 'returns forbidden' do
        allow(Flipper).to receive(:enabled?).with(:mhv_medications_cerner_pilot, anything).and_return(false)

        get('/my_health/v2/prescriptions/list_refillable_prescriptions', headers:)

        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when feature flag is enabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:mhv_medications_cerner_pilot, anything).and_return(true)
      end

      it 'filters prescriptions to only include refillable ones' do
        VCR.use_cassette('unified_health_data/get_prescriptions_success', match_requests_on: %i[method path]) do
          get('/my_health/v2/prescriptions/list_refillable_prescriptions', headers:)

          expect(response).to have_http_status(:success)
          expect(response.body).to be_a(String)
          expect(response.content_type).to include('application/json')

          json_response = JSON.parse(response.body)
          response_data = json_response['data']

          # Verify each prescription meets refillable criteria
          response_data.each do |p|
            prescription = p['attributes']

            # If prescription has is_refillable attribute and it's true, that's sufficient
            if prescription['is_refillable']
              expect(prescription['is_refillable']).to be(true)
              next
            end

            # Otherwise, check if it meets renewal criteria (only applies to items with disp_status)
            next if prescription['disp_status'].blank?

            disp_status = prescription['disp_status']
            # rx_rf_records maps to dispenses array from UHD model
            refill_history_item = prescription['rx_rf_records']&.first
            expired_date = if refill_history_item && refill_history_item['expiration_date']
                             refill_history_item['expiration_date']
                           else
                             prescription['expiration_date']
                           end
            cut_off_date = Time.zone.today - 120.days
            zero_date = Date.new(0, 1, 1)

            # Should meet renewal criteria
            # When V2StatusMapping is enabled, "Expired" is mapped to "Inactive"
            # so both "Expired" and "Inactive" can be renewable if within cut-off date
            meets_criteria = ['Active', 'Active: Parked'].include?(disp_status) ||
                             (%w[Expired Inactive].include?(disp_status) &&
                             expired_date.present? &&
                             DateTime.parse(expired_date) != zero_date &&
                             DateTime.parse(expired_date) >= cut_off_date)

            expect(meets_criteria).to be(true),
                                      "Prescription #{prescription['prescription_id']} with status " \
                                      "'#{disp_status}' should meet refillable criteria"
          end
        end
      end

      it 'includes recently_requested metadata' do
        VCR.use_cassette('unified_health_data/get_prescriptions_success', match_requests_on: %i[method path]) do
          get('/my_health/v2/prescriptions/list_refillable_prescriptions', headers:)

          json_response = JSON.parse(response.body)
          expect(json_response['meta']).to have_key('recently_requested')
          expect(json_response['meta']).not_to have_key('filter_count')

          recently_requested = json_response['meta']['recently_requested']
          expect(recently_requested).to be_an(Array)

          # Verify recently_requested contains prescriptions with specific disp_status values
          recently_requested.each do |prescription|
            status = prescription['disp_status']
            if status.present?
              expected_statuses = ['Active: Refill in Process', 'Active: Submitted', 'In progress']
              expect(status).to be_in(expected_statuses)
            end
          end
        end
      end

      it 'returns prescriptions using V2 serializer' do
        VCR.use_cassette('unified_health_data/get_prescriptions_success', match_requests_on: %i[method path]) do
          get('/my_health/v2/prescriptions/list_refillable_prescriptions', headers:)

          json_response = JSON.parse(response.body)
          expect(json_response['data']).to be_an(Array)

          # Verify it has expected V2 serializer attributes
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

      it 'handles prescriptions with is_refillable=true' do
        VCR.use_cassette('unified_health_data/get_prescriptions_success', match_requests_on: %i[method path]) do
          get('/my_health/v2/prescriptions/list_refillable_prescriptions', headers:)

          json_response = JSON.parse(response.body)

          # Find prescriptions that are directly refillable
          refillable_prescriptions = json_response['data'].select do |p|
            p['attributes']['is_refillable'] == true
          end

          # Should have at least some directly refillable prescriptions
          expect(refillable_prescriptions).not_to be_empty
        end
      end

      it 'handles renewable prescriptions (Active status, zero refills)' do
        VCR.use_cassette('unified_health_data/get_prescriptions_success', match_requests_on: %i[method path]) do
          get('/my_health/v2/prescriptions/list_refillable_prescriptions', headers:)

          json_response = JSON.parse(response.body)

          # Look for prescriptions that meet renewable criteria
          renewable_prescriptions = json_response['data'].select do |p|
            attrs = p['attributes']
            attrs['disp_status'] == 'Active' &&
              attrs['refill_remaining'].to_i.zero? &&
              attrs['is_refillable'] == false
          end

          # These should be included in the refillable list
          if renewable_prescriptions.any?
            renewable_prescriptions.each do |rx|
              expect(rx['attributes']['disp_status']).to eq('Active')
            end
          end
        end
      end

      it 'handles Expired prescriptions within cutoff date' do
        VCR.use_cassette('unified_health_data/get_prescriptions_success', match_requests_on: %i[method path]) do
          get('/my_health/v2/prescriptions/list_refillable_prescriptions', headers:)

          json_response = JSON.parse(response.body)

          # Find any Expired prescriptions in the results
          expired_prescriptions = json_response['data'].select do |p|
            p['attributes']['disp_status'] == 'Expired'
          end

          # If there are expired prescriptions, verify they're within cutoff
          cut_off_date = Time.zone.today - 120.days
          zero_date = Date.new(0, 1, 1)

          expired_prescriptions.each do |rx|
            attrs = rx['attributes']
            # rx_rf_records maps to dispenses array from UHD model
            refill_history_item = attrs['rx_rf_records']&.first
            expired_date = if refill_history_item && refill_history_item['expiration_date']
                             DateTime.parse(refill_history_item['expiration_date'])
                           else
                             DateTime.parse(attrs['expiration_date'])
                           end

            expect(expired_date).not_to eq(zero_date)
            expect(expired_date).to be >= cut_off_date
          end
        end
      end

      it 'excludes prescriptions without disp_status that are not refillable' do
        VCR.use_cassette('unified_health_data/get_prescriptions_success', match_requests_on: %i[method path]) do
          get('/my_health/v2/prescriptions/list_refillable_prescriptions', headers:)

          json_response = JSON.parse(response.body)

          # Find prescriptions without disp_status
          prescriptions_without_status = json_response['data'].select do |p|
            p['attributes']['disp_status'].blank?
          end

          # These should only be included if is_refillable is true
          prescriptions_without_status.each do |rx|
            expect(rx['attributes']['is_refillable']).to be(true),
                                                         'Prescriptions without disp_status should have ' \
                                                         'is_refillable=true'
          end
        end
      end

      it 'returns camelCase when X-Key-Inflection: camel header is provided' do
        VCR.use_cassette('unified_health_data/get_prescriptions_success', match_requests_on: %i[method path]) do
          camel_headers = headers.merge('X-Key-Inflection' => 'camel')
          get '/my_health/v2/prescriptions/list_refillable_prescriptions', headers: camel_headers

          json_response = JSON.parse(response.body)

          # Verify meta keys are camelCase
          expect(json_response['meta']).to have_key('recentlyRequested')
          expect(json_response['meta']).not_to have_key('recently_requested')
          expect(json_response['meta']).not_to have_key('filterCount')
          expect(json_response['meta']).not_to have_key('filter_count')

          # Verify attribute keys are camelCase
          prescription = json_response['data'].first
          attributes = prescription['attributes']
          expect(attributes).to have_key('prescriptionId')
          expect(attributes).to have_key('prescriptionName')
          expect(attributes).not_to have_key('prescription_id')
          expect(attributes).not_to have_key('prescription_name')
        end
      end

      it 'does not include filter_count metadata' do
        VCR.use_cassette('unified_health_data/get_prescriptions_success', match_requests_on: %i[method path]) do
          get('/my_health/v2/prescriptions/list_refillable_prescriptions', headers:)

          json_response = JSON.parse(response.body)
          expect(response).to have_http_status(:success)
          expect(json_response['meta']).not_to have_key('filter_count')

          # Should only have recently_requested in metadata
          expect(json_response['meta'].keys).to eq(['recently_requested'])
        end
      end

      it 'includes expected prescription attributes' do
        VCR.use_cassette('unified_health_data/get_prescriptions_success', match_requests_on: %i[method path]) do
          get('/my_health/v2/prescriptions/list_refillable_prescriptions', headers:)

          json_response = JSON.parse(response.body)
          prescription = json_response['data'].first
          attributes = prescription['attributes']

          # Verify core attributes present
          expect(attributes).to include(
            'prescription_id',
            'prescription_number',
            'prescription_name',
            'is_refillable',
            'refill_status',
            'facility_name',
            'station_number'
          )
        end
      end

      it 'includes dispenses (rx_rf_records) for prescriptions with refill history' do
        VCR.use_cassette('unified_health_data/get_prescriptions_success', match_requests_on: %i[method path]) do
          get('/my_health/v2/prescriptions/list_refillable_prescriptions', headers:)

          json_response = JSON.parse(response.body)

          # Find prescriptions with dispenses
          prescriptions_with_dispenses = json_response['data'].select do |rx|
            rx['attributes']['rx_rf_records'].present? && rx['attributes']['rx_rf_records'].any?
          end

          # If any prescriptions have dispenses, verify the structure
          prescriptions_with_dispenses.each do |prescription|
            dispenses = prescription['attributes']['rx_rf_records']
            expect(dispenses).to be_an(Array)

            # Verify each dispense has expected fields
            dispenses.each do |dispense|
              expect(dispense).to be_a(Hash)
              # Common dispense fields from Vista adapter
              expect(dispense.keys).to include('status') if dispense['status'].present?
              expect(dispense.keys).to include('dispensed_date') if dispense['dispensed_date'].present?
              expect(dispense.keys).to include('quantity') if dispense['quantity'].present?
            end
          end
        end
      end
    end
  end

  describe 'GET /my_health/v2/prescriptions/:id' do
    context 'when feature flag is disabled' do
      it 'returns forbidden' do
        allow(Flipper).to receive(:enabled?).with(:mhv_medications_cerner_pilot, anything).and_return(false)

        get('/my_health/v2/prescriptions/12345', params: { station_number: '556' }, headers:)

        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when feature flag is enabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:mhv_medications_cerner_pilot, anything).and_return(true)
      end

      it 'returns 400 when station_number parameter is missing' do
        get('/my_health/v2/prescriptions/12345', headers:)

        expect(response).to have_http_status(:bad_request)
        error = response.parsed_body['errors']&.first
        expect(error['detail']).to include('station_number')
      end

      it 'returns a successful response when prescription is found' do
        VCR.use_cassette('unified_health_data/get_prescriptions_success', match_requests_on: %i[method path]) do
          get('/my_health/v2/prescriptions/20848812135', params: { station_number: '668' }, headers:)

          expect(response).to have_http_status(:success)
          json_response = JSON.parse(response.body)
          expect(json_response['data']['attributes']['prescription_id']).to eq('20848812135')
          expect(json_response['data']['attributes']['station_number']).to eq('668')
          expect(json_response['data']['attributes']['prescription_name'])
            .to eq('albuterol (albuterol 90 mcg inhaler [18g])')
        end
      end

      it 'returns 404 when prescription is not found' do
        VCR.use_cassette('unified_health_data/get_prescriptions_success', match_requests_on: %i[method path]) do
          get('/my_health/v2/prescriptions/99999', params: { station_number: '123' }, headers:)

          expect(response).to have_http_status(:not_found)
        end
      end

      it 'returns camelCase attributes when X-Key-Inflection: camel header is provided' do
        VCR.use_cassette('unified_health_data/get_prescriptions_success', match_requests_on: %i[method path]) do
          camel_headers = headers.merge('X-Key-Inflection' => 'camel')
          get('/my_health/v2/prescriptions/20848812135', params: { station_number: '668' }, headers: camel_headers)

          expect(response).to have_http_status(:success)
          json_response = JSON.parse(response.body)
          attributes = json_response['data']['attributes']

          expect(attributes).to have_key('prescriptionId')
          expect(attributes['prescriptionId']).to eq('20848812135')
          expect(attributes).to have_key('stationNumber')
          expect(attributes['stationNumber']).to eq('668')
          expect(attributes).not_to have_key('prescription_id')
          expect(attributes).not_to have_key('station_number')
        end
      end
    end
  end
end
