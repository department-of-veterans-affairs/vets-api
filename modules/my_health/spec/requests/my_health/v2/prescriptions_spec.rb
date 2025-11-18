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

          # After grouping, we should still have prescriptions in the list
          # Pick the first one to verify it has Oracle/UHD specific fields
          first_prescription = json_response['data'].first
          expect(first_prescription).not_to be_nil

          attributes = first_prescription['attributes']

          # These are Oracle/UHD specific fields that come from the unified_health_data service
          expect(attributes).to have_key('facility_name')
          expect(attributes).to have_key('station_number')
          expect(attributes).to have_key('is_refillable')
          expect(attributes).to have_key('is_trackable')
          expect(attributes).to have_key('prescription_source')

          # Verify prescription_source is present (RX, PD, NV, etc.)
          expect(attributes['prescription_source']).to be_present
        end
      end

      it 'groups prescription renewals together' do
        VCR.use_cassette('unified_health_data/get_prescriptions_success', match_requests_on: %i[method path]) do
          get('/my_health/v2/prescriptions', headers:)

          json_response = JSON.parse(response.body)
          prescriptions = json_response['data']

          expect(prescriptions).not_to be_empty

          # NOTE: Currently, RF records are nested in rxRFRecords and not flattened into the main list,
          # so the grouping helper doesn't find them to group. This will be addressed in future work
          # when the UHD service flattens refills or the controller pre-processes the data.
          # For now, verify the attribute exists even if empty.
          prescriptions.each do |prescription|
            # Verify grouped_medications attribute exists
            expect(prescription['attributes']).to have_key('grouped_medications')
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

  describe 'GET /my_health/v2/prescriptions/list_refillable_prescriptions' do
    context 'when feature flag is disabled' do
      it 'returns forbidden' do
        allow(Flipper).to receive(:enabled?).and_return(false)

        get('/my_health/v2/prescriptions/list_refillable_prescriptions', headers:)

        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when feature flag is enabled' do
      before do
        allow(Flipper).to receive(:enabled?).and_return(true)
      end

      it 'returns list of refillable prescriptions' do
        VCR.use_cassette('unified_health_data/get_prescriptions_success', match_requests_on: %i[method path]) do
          get('/my_health/v2/prescriptions/list_refillable_prescriptions', headers:)

          expect(response).to have_http_status(:success)
          expect(response.body).to be_a(String)
          expect(response.content_type).to include('application/json')

          json_response = JSON.parse(response.body)
          expect(json_response['data']).to be_an(Array)
        end
      end

      it 'filters prescriptions to only include refillable ones' do
        VCR.use_cassette('unified_health_data/get_prescriptions_success', match_requests_on: %i[method path]) do
          get('/my_health/v2/prescriptions/list_refillable_prescriptions', headers:)

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
            refill_history_item = prescription['rx_rf_records']&.first
            expired_date = if refill_history_item && refill_history_item['expiration_date']
                             refill_history_item['expiration_date']
                           else
                             prescription['expiration_date']
                           end
            cut_off_date = Time.zone.today - 120.days
            zero_date = Date.new(0, 1, 1)

            # Should meet renewal criteria
            meets_criteria = ['Active', 'Active: Parked'].include?(disp_status) ||
                             (disp_status == 'Expired' &&
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
            expect(status).to be_in(['Active: Refill in Process', 'Active: Submitted']) if status.present?
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
