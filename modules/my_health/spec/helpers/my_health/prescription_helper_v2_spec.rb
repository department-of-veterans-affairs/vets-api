# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MyHealth::PrescriptionHelperV2 do
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

  def build_prescription(attrs = {})
    defaults = {
      id: SecureRandom.uuid,
      prescription_name: 'Test Med',
      disp_status: 'Active',
      is_refillable: false,
      is_renewable: false,
      is_trackable: false,
      dispensed_date: nil,
      station_number: '123',
      prescription_source: 'VA',
      dispenses: []
    }
    merged = defaults.merge(attrs)
    merged[:id] = attrs[:prescription_id] if attrs.key?(:prescription_id)
    OpenStruct.new(merged)
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

    describe '#renewable' do
      it 'returns true when is_renewable is true (Oracle Health)' do
        prescription = build_prescription(is_renewable: true)

        expect(helper.renewable(prescription)).to be true
      end

      it 'returns false when is_renewable is false (Oracle Health)' do
        prescription = build_prescription(is_renewable: false)

        expect(helper.renewable(prescription)).to be false
      end

      it 'falls through to legacy logic when is_renewable is nil' do
        prescription = build_prescription(is_renewable: nil, disp_status: 'Active', is_refillable: false)

        expect(helper.renewable(prescription)).to be true
      end

      it 'returns true for Expired status within cutoff (legacy VistA)' do
        prescription = build_prescription(
          is_renewable: nil,
          disp_status: 'Expired',
          expiration_date: 90.days.ago.to_date,
          is_refillable: false
        )

        expect(helper.renewable(prescription)).to be true
      end

      it 'returns true for Inactive status within cutoff (V2StatusMapping)' do
        # When V2StatusMapping is enabled, "Expired" gets mapped to "Inactive"
        prescription = build_prescription(
          is_renewable: nil,
          disp_status: 'Inactive',
          expiration_date: 90.days.ago.to_date,
          is_refillable: false
        )

        expect(helper.renewable(prescription)).to be true
      end

      it 'returns false for Inactive status outside cutoff' do
        prescription = build_prescription(
          is_renewable: nil,
          disp_status: 'Inactive',
          expiration_date: 121.days.ago.to_date,
          is_refillable: false
        )

        expect(helper.renewable(prescription)).to be false
      end

      it 'returns true for Active status with zero refills' do
        prescription = build_prescription(
          is_renewable: nil,
          disp_status: 'Active',
          refill_remaining: 0,
          is_refillable: false
        )

        expect(helper.renewable(prescription)).to be true
      end

      it 'returns false for non-renewable statuses' do
        %w[Discontinued Transferred Unknown].each do |status|
          prescription = build_prescription(is_renewable: nil, disp_status: status)
          expect(helper.renewable(prescription)).to be false
        end
      end

      context 'when disp_status is Active: Parked with nil dispenses' do
        it 'does not raise and returns false' do
          prescription = build_prescription(
            is_renewable: nil,
            disp_status: 'Active: Parked',
            is_refillable: false,
            refill_remaining: 0,
            dispenses: nil
          )

          expect { helper.renewable(prescription) }.not_to raise_error
          expect(helper.renewable(prescription)).to be false
        end
      end

      context 'when disp_status is Active: Parked with empty dispenses' do
        it 'returns false' do
          prescription = build_prescription(
            is_renewable: nil,
            disp_status: 'Active: Parked',
            is_refillable: false,
            refill_remaining: 0,
            dispenses: [{}]
          )

          expect(helper.renewable(prescription)).to be false
        end
      end

      context 'when disp_status is Active: Parked with non-empty dispenses' do
        it 'returns true' do
          prescription = build_prescription(
            is_renewable: nil,
            disp_status: 'Active: Parked',
            is_refillable: false,
            refill_remaining: 0,
            dispenses: [{ expiration_date: Time.zone.today.to_s }]
          )

          expect(helper.renewable(prescription)).to be true
        end
      end
    end
  end

  describe 'MyHealth::PrescriptionHelperV2::Sorting' do
    let(:helper_class) do
      Class.new do
        include MyHealth::PrescriptionHelperV2::Sorting
      end
    end
    let(:helper) { helper_class.new }

    describe '#apply_sorting' do
      let(:prescription1) do
        double('prescription1',
               prescription_name: 'Zoloft',
               disp_status: 'Active',
               dispensed_date: Date.new(2024, 1, 1),
               prescription_source: 'VA',
               dispenses: [],
               orderable_item: nil)
      end

      let(:prescription2) do
        double('prescription2',
               prescription_name: 'Aspirin',
               disp_status: 'Active',
               dispensed_date: Date.new(2024, 3, 1),
               prescription_source: 'VA',
               dispenses: [],
               orderable_item: nil)
      end

      let(:prescription3) do
        double('prescription3',
               prescription_name: 'Metformin',
               disp_status: 'Inactive',
               dispensed_date: Date.new(2024, 2, 1),
               prescription_source: 'VA',
               dispenses: [],
               orderable_item: nil)
      end

      let(:prescriptions) { [prescription1, prescription2, prescription3] }

      let(:resource) do
        records = prescriptions.dup
        metadata = {}
        double('resource').tap do |r|
          allow(r).to receive_messages(records:, metadata:)
          allow(r).to receive(:records=) { |new_records| records.replace(new_records) }
          allow(r).to receive(:metadata=) { |new_metadata| metadata.replace(new_metadata) }
        end
      end

      before do
        allow(prescription1).to receive(:respond_to?).with(:dispenses).and_return(true)
        allow(prescription1).to receive(:respond_to?).with(:sorted_dispensed_date).and_return(false)
        allow(prescription2).to receive(:respond_to?).with(:dispenses).and_return(true)
        allow(prescription2).to receive(:respond_to?).with(:sorted_dispensed_date).and_return(false)
        allow(prescription3).to receive(:respond_to?).with(:dispenses).and_return(true)
        allow(prescription3).to receive(:respond_to?).with(:sorted_dispensed_date).and_return(false)
      end

      context 'when sort_param is nil' do
        it 'applies default sorting' do
          result = helper.apply_sorting(resource, nil)

          expect(result.metadata[:sort]).to eq({
                                                 'disp_status' => 'ASC',
                                                 'prescription_name' => 'ASC',
                                                 'dispensed_date' => 'DESC'
                                               })
        end
      end

      context 'when sort_param is alphabetical-rx-name' do
        it 'sorts by prescription_name ascending with secondary sort by dispensed_date descending' do
          result = helper.apply_sorting(resource, 'alphabetical-rx-name')

          expect(result.metadata[:sort]).to eq({
                                                 'prescription_name' => 'ASC',
                                                 'dispensed_date' => 'DESC'
                                               })
        end
      end

      context 'when sort_param is last-fill-date' do
        it 'sorts by dispensed_date descending with secondary sort by prescription_name ascending' do
          result = helper.apply_sorting(resource, 'last-fill-date')

          expect(result.metadata[:sort]).to eq({
                                                 'dispensed_date' => 'DESC',
                                                 'prescription_name' => 'ASC'
                                               })
        end
      end

      context 'when sort_param is unknown' do
        it 'applies default sorting' do
          result = helper.apply_sorting(resource, 'unknown-sort')

          expect(result.metadata[:sort]).to eq({
                                                 'disp_status' => 'ASC',
                                                 'prescription_name' => 'ASC',
                                                 'dispensed_date' => 'DESC'
                                               })
        end
      end
    end

    describe '#build_sort_metadata' do
      it 'returns default metadata for -alphabetical-rx-name (unrecognized sort param)' do
        result = helper.build_sort_metadata('-alphabetical-rx-name')
        # Falls back to default since -alphabetical-rx-name is not a recognized case
        expect(result).to eq({
                               'disp_status' => 'ASC',
                               'prescription_name' => 'ASC',
                               'dispensed_date' => 'DESC'
                             })
      end

      it 'returns last-fill-date metadata for last-fill-date' do
        result = helper.build_sort_metadata('last-fill-date')
        expect(result).to eq({
                               'dispensed_date' => 'DESC',
                               'prescription_name' => 'ASC'
                             })
      end

      it 'returns default metadata for unrecognized sort param' do
        result = helper.build_sort_metadata('-last-fill-date')
        expect(result).to eq({
                               'disp_status' => 'ASC',
                               'prescription_name' => 'ASC',
                               'dispensed_date' => 'DESC'
                             })
      end

      it 'returns alphabetical sort metadata for alphabetical-rx-name' do
        result = helper.build_sort_metadata('alphabetical-rx-name')
        expect(result).to eq({
                               'prescription_name' => 'ASC',
                               'dispensed_date' => 'DESC'
                             })
      end
    end
  end
end
