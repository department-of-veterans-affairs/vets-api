# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MyHealth::PrescriptionHelperV2 do
  describe MyHealth::PrescriptionHelperV2::Filtering do
    let(:test_class) do
      Class.new do
        include MyHealth::PrescriptionHelperV2::Filtering
      end
    end

    let(:helper) { test_class.new }

    describe '#check_renewable' do
      context 'when item has is_renewable = true' do
        it 'returns true' do
          item = double('Prescription', is_renewable: true)
          allow(item).to receive(:respond_to?).with(:is_renewable).and_return(true)

          expect(helper.check_renewable(item)).to be true
        end
      end

      context 'when item has is_renewable = false' do
        it 'returns false' do
          item = double('Prescription', is_renewable: false)
          allow(item).to receive(:respond_to?).with(:is_renewable).and_return(true)

          expect(helper.check_renewable(item)).to be false
        end
      end

      context 'when item has is_renewable = nil' do
        it 'returns false' do
          item = double('Prescription', is_renewable: nil)
          allow(item).to receive(:respond_to?).with(:is_renewable).and_return(true)

          expect(helper.check_renewable(item)).to be false
        end
      end

      context 'when item does not respond to is_renewable' do
        it 'returns false' do
          item = double('Prescription')
          allow(item).to receive(:respond_to?).with(:is_renewable).and_return(false)

          expect(helper.check_renewable(item)).to be false
        end
      end
    end

    describe '#filter_data_by_refill_and_renew' do
      it 'includes items that are refillable' do
        refillable_item = double('Prescription', is_refillable: true, is_renewable: false)
        allow(refillable_item).to receive(:respond_to?).with(:is_renewable).and_return(true)

        non_refillable_item = double('Prescription', is_refillable: false, is_renewable: false)
        allow(non_refillable_item).to receive(:respond_to?).with(:is_renewable).and_return(true)

        data = [refillable_item, non_refillable_item]
        result = helper.filter_data_by_refill_and_renew(data)

        expect(result).to include(refillable_item)
        expect(result).not_to include(non_refillable_item)
      end

      it 'includes items that are renewable' do
        renewable_item = double('Prescription', is_refillable: false, is_renewable: true)
        allow(renewable_item).to receive(:respond_to?).with(:is_renewable).and_return(true)

        non_renewable_item = double('Prescription', is_refillable: false, is_renewable: false)
        allow(non_renewable_item).to receive(:respond_to?).with(:is_renewable).and_return(true)

        data = [renewable_item, non_renewable_item]
        result = helper.filter_data_by_refill_and_renew(data)

        expect(result).to include(renewable_item)
        expect(result).not_to include(non_renewable_item)
      end

      it 'includes items that are both refillable and renewable' do
        both_item = double('Prescription', is_refillable: true, is_renewable: true)
        allow(both_item).to receive(:respond_to?).with(:is_renewable).and_return(true)

        data = [both_item]
        result = helper.filter_data_by_refill_and_renew(data)

        expect(result).to include(both_item)
      end

      it 'excludes items that are neither refillable nor renewable' do
        neither_item = double('Prescription', is_refillable: false, is_renewable: false)
        allow(neither_item).to receive(:respond_to?).with(:is_renewable).and_return(true)

        data = [neither_item]
        result = helper.filter_data_by_refill_and_renew(data)

        expect(result).to be_empty
      end

      it 'returns empty array for empty input' do
        result = helper.filter_data_by_refill_and_renew([])
        expect(result).to eq([])
      end

      it 'handles mixed collection correctly' do
        refillable = double('Prescription', is_refillable: true, is_renewable: false)
        allow(refillable).to receive(:respond_to?).with(:is_renewable).and_return(true)

        renewable = double('Prescription', is_refillable: false, is_renewable: true)
        allow(renewable).to receive(:respond_to?).with(:is_renewable).and_return(true)

        neither = double('Prescription', is_refillable: false, is_renewable: false)
        allow(neither).to receive(:respond_to?).with(:is_renewable).and_return(true)

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
          renewable_item = double('Prescription', is_renewable: true)
          allow(renewable_item).to receive(:respond_to?).with(:is_renewable).and_return(true)

          non_renewable_item = double('Prescription', is_renewable: false)
          allow(non_renewable_item).to receive(:respond_to?).with(:is_renewable).and_return(true)

          data = [renewable_item, non_renewable_item]
          filter_params = { isRenewable: { eq: 'true' } }

          result = helper.apply_custom_filters(data, filter_params)

          expect(result).to include(renewable_item)
          expect(result).not_to include(non_renewable_item)
        end

        it 'filters for non-renewable items when isRenewable eq is false' do
          renewable_item = double('Prescription', is_renewable: true)
          allow(renewable_item).to receive(:respond_to?).with(:is_renewable).and_return(true)

          non_renewable_item = double('Prescription', is_renewable: false)
          allow(non_renewable_item).to receive(:respond_to?).with(:is_renewable).and_return(true)

          data = [renewable_item, non_renewable_item]
          filter_params = { isRenewable: { eq: 'false' } }

          result = helper.apply_custom_filters(data, filter_params)

          expect(result).not_to include(renewable_item)
          expect(result).to include(non_renewable_item)
        end

        it 'handles boolean true value' do
          renewable_item = double('Prescription', is_renewable: true)
          allow(renewable_item).to receive(:respond_to?).with(:is_renewable).and_return(true)

          data = [renewable_item]
          filter_params = { isRenewable: { eq: true } }

          result = helper.apply_custom_filters(data, filter_params)

          expect(result).to include(renewable_item)
        end
      end

      describe 'shipped filter' do
        it 'filters for shipped items when shipped eq is true' do
          trackable_item = double('Prescription', is_trackable: true)
          allow(trackable_item).to receive(:respond_to?).with(:is_trackable).and_return(true)

          non_trackable_item = double('Prescription', is_trackable: false)
          allow(non_trackable_item).to receive(:respond_to?).with(:is_trackable).and_return(true)

          data = [trackable_item, non_trackable_item]
          filter_params = { shipped: { eq: 'true' } }

          result = helper.apply_custom_filters(data, filter_params)

          expect(result).to include(trackable_item)
          expect(result).not_to include(non_trackable_item)
        end

        it 'filters for non-shipped items when shipped eq is false' do
          trackable_item = double('Prescription', is_trackable: true)
          allow(trackable_item).to receive(:respond_to?).with(:is_trackable).and_return(true)

          non_trackable_item = double('Prescription', is_trackable: false)
          allow(non_trackable_item).to receive(:respond_to?).with(:is_trackable).and_return(true)

          data = [trackable_item, non_trackable_item]
          filter_params = { shipped: { eq: 'false' } }

          result = helper.apply_custom_filters(data, filter_params)

          expect(result).not_to include(trackable_item)
          expect(result).to include(non_trackable_item)
        end

        it 'handles items that do not respond to is_trackable' do
          item_without_trackable = double('Prescription')
          allow(item_without_trackable).to receive(:respond_to?).with(:is_trackable).and_return(false)

          data = [item_without_trackable]
          filter_params = { shipped: { eq: 'true' } }

          result = helper.apply_custom_filters(data, filter_params)

          expect(result).to be_empty
        end
      end

      describe 'combined filters' do
        it 'applies both isRenewable and shipped filters' do
          renewable_trackable = double('Prescription', is_renewable: true, is_trackable: true)
          allow(renewable_trackable).to receive(:respond_to?).with(:is_renewable).and_return(true)
          allow(renewable_trackable).to receive(:respond_to?).with(:is_trackable).and_return(true)

          renewable_non_trackable = double('Prescription', is_renewable: true, is_trackable: false)
          allow(renewable_non_trackable).to receive(:respond_to?).with(:is_renewable).and_return(true)
          allow(renewable_non_trackable).to receive(:respond_to?).with(:is_trackable).and_return(true)

          non_renewable_trackable = double('Prescription', is_renewable: false, is_trackable: true)
          allow(non_renewable_trackable).to receive(:respond_to?).with(:is_renewable).and_return(true)
          allow(non_renewable_trackable).to receive(:respond_to?).with(:is_trackable).and_return(true)

          data = [renewable_trackable, renewable_non_trackable, non_renewable_trackable]
          filter_params = { isRenewable: { eq: 'true' }, shipped: { eq: 'true' } }

          result = helper.apply_custom_filters(data, filter_params)

          expect(result).to eq([renewable_trackable])
        end
      end

      describe 'edge cases' do
        it 'returns data unchanged when filter_params is nil' do
          item = double('Prescription')
          data = [item]

          result = helper.apply_custom_filters(data, nil)

          expect(result).to eq(data)
        end

        it 'returns data unchanged when filter_params is empty' do
          item = double('Prescription')
          data = [item]

          result = helper.apply_custom_filters(data, {})

          expect(result).to eq(data)
        end

        it 'returns data unchanged when filter has no eq value' do
          item = double('Prescription')
          data = [item]

          result = helper.apply_custom_filters(data, { isRenewable: {} })

          expect(result).to eq(data)
        end

        it 'returns empty array when data is empty' do
          result = helper.apply_custom_filters([], { isRenewable: { eq: 'true' } })

          expect(result).to eq([])
        end
      end
    end
  end

  describe MyHealth::PrescriptionHelperV2::Sorting do
    let(:test_class) do
      Class.new do
        include MyHealth::PrescriptionHelperV2::Sorting
      end
    end

    let(:helper) { test_class.new }

    let(:prescription_a) do
      OpenStruct.new(
        prescription_name: 'Alpha Medication',
        disp_status: 'Active',
        dispensed_date: Date.new(2024, 1, 15)
      )
    end

    let(:prescription_b) do
      OpenStruct.new(
        prescription_name: 'Beta Medication',
        disp_status: 'Inactive',
        dispensed_date: Date.new(2024, 2, 20)
      )
    end

    let(:prescription_c) do
      OpenStruct.new(
        prescription_name: 'Charlie Medication',
        disp_status: 'Active',
        dispensed_date: Date.new(2024, 3, 10)
      )
    end

    let(:prescriptions) { [prescription_b, prescription_c, prescription_a] }

    let(:resource) do
      Struct.new(:records, :metadata).new(prescriptions, {})
    end

    describe '#apply_sorting' do
      context 'when sort_param is nil' do
        it 'applies default sorting' do
          result = helper.apply_sorting(resource, nil)

          expect(result.metadata[:sort]).to be_present
          expect(result.metadata[:sort]).to include('disp_status' => 'ASC')
        end
      end

      context 'when sort_param is alphabetical-rx-name' do
        it 'sorts by prescription_name ascending' do
          result = helper.apply_sorting(resource, 'alphabetical-rx-name')

          expect(result.metadata[:sort]).to include('prescription_name' => 'ASC')
        end

        it 'sorts by prescription_name descending with negative prefix' do
          result = helper.apply_sorting(resource, '-alphabetical-rx-name')

          expect(result.metadata[:sort]).to include('prescription_name' => 'DESC')
        end
      end

      context 'when sort_param is last-fill-date' do
        it 'sorts by dispensed_date ascending' do
          result = helper.apply_sorting(resource, 'last-fill-date')

          expect(result.metadata[:sort]).to include('dispensed_date' => 'ASC')
        end

        it 'sorts by dispensed_date descending with negative prefix' do
          result = helper.apply_sorting(resource, '-last-fill-date')

          expect(result.metadata[:sort]).to include('dispensed_date' => 'DESC')
        end
      end

      context 'when sort_param is unknown' do
        it 'applies default sorting' do
          result = helper.apply_sorting(resource, 'unknown-sort')

          expect(result.metadata[:sort]).to include('disp_status' => 'ASC')
        end
      end
    end

    describe '#build_sort_metadata' do
      it 'returns default metadata for nil param' do
        metadata = helper.build_sort_metadata(nil)

        expect(metadata).to include('disp_status' => 'ASC')
        expect(metadata).to include('prescription_name' => 'ASC')
        expect(metadata).to include('dispensed_date' => 'DESC')
      end

      it 'returns alphabetical metadata for alphabetical-rx-name' do
        metadata = helper.build_sort_metadata('alphabetical-rx-name')

        expect(metadata).to include('prescription_name' => 'ASC')
      end

      it 'returns descending alphabetical metadata for -alphabetical-rx-name' do
        metadata = helper.build_sort_metadata('-alphabetical-rx-name')

        expect(metadata).to include('prescription_name' => 'DESC')
      end

      it 'returns last-fill-date metadata for last-fill-date' do
        metadata = helper.build_sort_metadata('last-fill-date')

        expect(metadata).to include('dispensed_date' => 'ASC')
      end

      it 'returns descending last-fill-date metadata for -last-fill-date' do
        metadata = helper.build_sort_metadata('-last-fill-date')

        expect(metadata).to include('dispensed_date' => 'DESC')
      end
    end
  end
end
