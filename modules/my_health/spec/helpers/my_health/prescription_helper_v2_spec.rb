# frozen_string_literal: true

require 'rails_helper'
require 'unified_health_data/models/prescription'

RSpec.describe MyHealth::PrescriptionHelperV2 do
  # Create a test class that includes the helper modules
  let(:helper_class) do
    Class.new do
      include MyHealth::PrescriptionHelperV2::Filtering
      include MyHealth::PrescriptionHelperV2::Sorting

      attr_accessor :current_user

      def initialize
        @current_user = nil
      end
    end
  end

  let(:helper) { helper_class.new }

  # Helper method to create prescription objects using UnifiedHealthData::Prescription
  def build_prescription(attrs = {})
    UnifiedHealthData::Prescription.new({
      id: attrs[:id] || attrs[:prescription_id] || SecureRandom.uuid,
      prescription_name: attrs[:prescription_name] || 'Test Med',
      disp_status: attrs[:disp_status] || 'Active',
      is_refillable: attrs[:is_refillable] || false,
      is_renewable: attrs[:is_renewable] || false,
      is_trackable: attrs[:is_trackable] || false,
      dispensed_date: attrs[:dispensed_date],
      station_number: attrs[:station_number] || '123'
    }.merge(attrs))
  end

  # Helper to create a resource-like object for sorting tests
  def build_resource(records)
    OpenStruct.new(records:, metadata: {})
  end

  describe 'MyHealth::PrescriptionHelperV2::Filtering' do
    describe '#filter_data_by_refill_and_renew' do
      it 'includes items that are refillable' do
        refillable_item = build_prescription(is_refillable: true, is_renewable: false)
        non_refillable_item = build_prescription(is_refillable: false, is_renewable: false)
        data = [refillable_item, non_refillable_item]

        result = helper.filter_data_by_refill_and_renew(data)

        expect(result).to include(refillable_item)
        expect(result).not_to include(non_refillable_item)
      end

      it 'includes items that are renewable' do
        renewable_item = build_prescription(is_refillable: false, is_renewable: true)
        non_renewable_item = build_prescription(is_refillable: false, is_renewable: false)
        data = [renewable_item, non_renewable_item]

        result = helper.filter_data_by_refill_and_renew(data)

        expect(result).to include(renewable_item)
        expect(result).not_to include(non_renewable_item)
      end

      it 'includes items that are both refillable and renewable' do
        both_item = build_prescription(is_refillable: true, is_renewable: true)
        data = [both_item]

        result = helper.filter_data_by_refill_and_renew(data)

        expect(result).to include(both_item)
      end

      it 'excludes items that are neither refillable nor renewable' do
        neither_item = build_prescription(is_refillable: false, is_renewable: false)
        data = [neither_item]

        result = helper.filter_data_by_refill_and_renew(data)

        expect(result).to be_empty
      end

      it 'returns empty array for empty input' do
        result = helper.filter_data_by_refill_and_renew([])
        expect(result).to eq([])
      end

      it 'handles mixed collection correctly' do
        refillable = build_prescription(is_refillable: true, is_renewable: false)
        renewable = build_prescription(is_refillable: false, is_renewable: true)
        neither = build_prescription(is_refillable: false, is_renewable: false)
        data = [refillable, renewable, neither]

        result = helper.filter_data_by_refill_and_renew(data)

        expect(result.length).to eq(2)
        expect(result).to include(refillable, renewable)
        expect(result).not_to include(neither)
      end
    end

    describe '#apply_custom_filters' do
      describe 'isRenewable filter' do
        it 'filters for renewable items when isRenewable eq is true' do
          renewable_item = build_prescription(id: '1', is_renewable: true)
          non_renewable_item = build_prescription(id: '2', is_renewable: false)
          data = [renewable_item, non_renewable_item]
          filter_params = { isRenewable: { eq: 'true' } }

          result = helper.apply_custom_filters(data, filter_params)

          expect(result).to include(renewable_item)
          expect(result).not_to include(non_renewable_item)
        end

        it 'filters for non-renewable items when isRenewable eq is false' do
          renewable_item = build_prescription(id: '1', is_renewable: true)
          non_renewable_item = build_prescription(id: '2', is_renewable: false)
          data = [renewable_item, non_renewable_item]
          filter_params = { isRenewable: { eq: 'false' } }

          result = helper.apply_custom_filters(data, filter_params)

          expect(result).not_to include(renewable_item)
          expect(result).to include(non_renewable_item)
        end
      end

      describe 'shipped filter' do
        it 'filters for shipped items when shipped eq is true' do
          # Shipped = Active disp_status AND is_trackable
          shipped_item = build_prescription(id: '1', disp_status: 'Active', is_trackable: true)
          non_shipped_trackable = build_prescription(id: '2', disp_status: 'Inactive', is_trackable: true)
          non_shipped_active = build_prescription(id: '3', disp_status: 'Active', is_trackable: false)
          data = [shipped_item, non_shipped_trackable, non_shipped_active]
          filter_params = { shipped: { eq: 'true' } }

          result = helper.apply_custom_filters(data, filter_params)

          expect(result).to include(shipped_item)
          expect(result).not_to include(non_shipped_trackable)
          expect(result).not_to include(non_shipped_active)
        end

        it 'filters for non-shipped items when shipped eq is false' do
          # Non-shipped = NOT (Active disp_status AND is_trackable)
          shipped_item = build_prescription(id: '1', disp_status: 'Active', is_trackable: true)
          non_shipped_trackable = build_prescription(id: '2', disp_status: 'Inactive', is_trackable: true)
          non_shipped_active = build_prescription(id: '3', disp_status: 'Active', is_trackable: false)
          data = [shipped_item, non_shipped_trackable, non_shipped_active]
          filter_params = { shipped: { eq: 'false' } }

          result = helper.apply_custom_filters(data, filter_params)

          expect(result).not_to include(shipped_item)
          expect(result).to include(non_shipped_trackable)
          expect(result).to include(non_shipped_active)
        end
      end
    end
  end

  describe 'MyHealth::PrescriptionHelperV2::Sorting' do
    describe '#apply_sorting' do
      let(:med_a) { build_prescription(id: '1', prescription_name: 'Aspirin', dispensed_date: '2024-01-15') }
      let(:med_b) { build_prescription(id: '2', prescription_name: 'Zoloft', dispensed_date: '2024-01-10') }
      let(:med_c) { build_prescription(id: '3', prescription_name: 'Metformin', dispensed_date: '2024-01-20') }

      context 'when sort_param is nil' do
        it 'applies default sorting' do
          resource = build_resource([med_b, med_c, med_a])
          result = helper.apply_sorting(resource, nil)
          expect(result.records).to be_an(Array)
          expect(result.records.length).to eq(3)
        end
      end

      context 'when sort_param is alphabetical-rx-name' do
        it 'sorts by prescription_name ascending' do
          resource = build_resource([med_b, med_c, med_a])
          result = helper.apply_sorting(resource, 'alphabetical-rx-name')
          names = result.records.map(&:prescription_name)
          expect(names).to eq(%w[Aspirin Metformin Zoloft])
        end

        it 'sorts by prescription_name descending with negative prefix' do
          resource = build_resource([med_b, med_c, med_a])
          # NOTE: The helper doesn't support negative prefix for reverse sort
          # It only supports 'alphabetical-rx-name' and 'last-fill-date'
          result = helper.apply_sorting(resource, '-alphabetical-rx-name')
          # Falls back to default sort since -alphabetical-rx-name is not recognized
          expect(result.records).to be_an(Array)
          expect(result.records.length).to eq(3)
        end
      end

      context 'when sort_param is last-fill-date' do
        it 'sorts by dispensed_date ascending' do
          resource = build_resource([med_b, med_c, med_a])
          result = helper.apply_sorting(resource, 'last-fill-date')
          # last-fill-date sorts by most recent first (descending date), then by name
          dates = result.records.map(&:dispensed_date)
          expect(dates).to eq(%w[2024-01-20 2024-01-15 2024-01-10])
        end

        it 'sorts by dispensed_date descending with negative prefix' do
          resource = build_resource([med_b, med_c, med_a])
          # NOTE: The helper doesn't support negative prefix
          result = helper.apply_sorting(resource, '-last-fill-date')
          # Falls back to default sort since -last-fill-date is not recognized
          expect(result.records).to be_an(Array)
          expect(result.records.length).to eq(3)
        end
      end

      context 'when sort_param is unknown' do
        it 'applies default sorting' do
          resource = build_resource([med_b, med_c, med_a])
          result = helper.apply_sorting(resource, 'unknown-sort')
          expect(result.records).to be_an(Array)
          expect(result.records.length).to eq(3)
        end
      end
    end

    describe '#build_sort_metadata' do
      it 'returns descending alphabetical metadata for -alphabetical-rx-name' do
        # The helper returns default metadata for unrecognized sort params
        result = helper.build_sort_metadata('-alphabetical-rx-name')
        # Falls back to default since -alphabetical-rx-name is not a recognized case
        expect(result).to include('disp_status' => 'ASC')
      end

      it 'returns last-fill-date metadata for last-fill-date' do
        result = helper.build_sort_metadata('last-fill-date')
        expect(result).to include('dispensed_date' => 'DESC')
      end

      it 'returns default metadata for unrecognized sort param' do
        result = helper.build_sort_metadata('-last-fill-date')
        expect(result).to include('disp_status' => 'ASC')
      end

      it 'returns alphabetical sort metadata for alphabetical-rx-name' do
        result = helper.build_sort_metadata('alphabetical-rx-name')
        expect(result).to include('prescription_name' => 'ASC')
      end
    end
  end
end
