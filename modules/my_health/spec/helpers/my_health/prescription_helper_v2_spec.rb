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

    describe '#extract_last_fill_date (private method via get_sorted_dispensed_date)' do
      # Tests the private extract_last_fill_date method via its caller get_sorted_dispensed_date
      # This method extracts the correct date for "last filled" sorting from dispenses.
      #
      # Both Vista and Oracle Health adapters now provide dispensed_date in dispenses:
      # - Vista: dispensed_date from VistA dispensedDate field
      # - Oracle Health: dispensed_date from FHIR whenHandedOver field

      context 'with Vista prescriptions' do
        it 'uses dispensed_date from dispenses for sorting' do
          # Vista dispenses have BOTH dispensed_date and refill_date
          # dispensed_date is the correct field for "when the medication was filled"
          med = double('vista_med',
                       prescription_name: 'Vista Med',
                       dispensed_date: Date.new(2024, 1, 1),
                       dispenses: [
                         { dispensed_date: Date.new(2024, 6, 15), refill_date: Date.new(2024, 6, 10) },
                         { dispensed_date: Date.new(2024, 3, 20), refill_date: Date.new(2024, 3, 15) }
                       ])
          allow(med).to receive(:respond_to?).with(:dispenses).and_return(true)
          allow(med).to receive(:respond_to?).with(:sorted_dispensed_date).and_return(false)

          result = helper.send(:get_sorted_dispensed_date, med)

          # Should return 2024-06-15 (the max dispensed_date)
          expect(result).to eq(Date.new(2024, 6, 15))
        end

        it 'ignores nil dispensed_date entries and uses max of available dates' do
          # When some dispenses have dispensed_date and others don't, we use what's available.
          med = double('vista_med_mixed_dispenses',
                       prescription_name: 'Vista Med',
                       dispensed_date: Date.new(2024, 1, 1),
                       dispenses: [
                         { dispensed_date: Date.new(2024, 3, 15), refill_date: Date.new(2024, 3, 10) },
                         { dispensed_date: nil, refill_date: Date.new(2024, 6, 10) },
                         { dispensed_date: Date.new(2024, 5, 20), refill_date: Date.new(2024, 5, 15) }
                       ])
          allow(med).to receive(:respond_to?).with(:dispenses).and_return(true)
          allow(med).to receive(:respond_to?).with(:sorted_dispensed_date).and_return(false)

          result = helper.send(:get_sorted_dispensed_date, med)

          # Should return 2024-05-20, the max of the available dispensed_dates (ignoring nil)
          expect(result).to eq(Date.new(2024, 5, 20))
        end

        it 'falls back to prescription dispensed_date when dispenses have no dispensed_date' do
          med = double('med_empty_dispenses',
                       prescription_name: 'Med',
                       dispensed_date: Date.new(2024, 1, 1),
                       dispenses: [
                         { dispensed_date: nil, refill_date: nil }
                       ])
          allow(med).to receive(:respond_to?).with(:dispenses).and_return(true)
          allow(med).to receive(:respond_to?).with(:sorted_dispensed_date).and_return(false)

          result = helper.send(:get_sorted_dispensed_date, med)

          # Should fall back to prescription's dispensed_date when no dispense dates available
          expect(result).to eq(Date.new(2024, 1, 1))
        end
      end

      context 'with Oracle Health prescriptions' do
        it 'uses dispensed_date from dispenses (mapped from FHIR whenHandedOver)' do
          # Oracle Health adapter now provides dispensed_date (from FHIR whenHandedOver)
          med = double('oracle_med',
                       prescription_name: 'Oracle Med',
                       dispensed_date: Date.new(2024, 1, 1),
                       dispenses: [
                         { dispensed_date: Date.new(2024, 6, 15) },
                         { dispensed_date: Date.new(2024, 3, 20) }
                       ])
          allow(med).to receive(:respond_to?).with(:dispenses).and_return(true)
          allow(med).to receive(:respond_to?).with(:sorted_dispensed_date).and_return(false)

          result = helper.send(:get_sorted_dispensed_date, med)

          # Should use max dispensed_date
          expect(result).to eq(Date.new(2024, 6, 15))
        end
      end
    end

    describe 'last-fill-date sorting integration' do
      # Integration tests verifying prescriptions from different sources sort correctly.
      # Tests mixed Vista/Oracle Health, Vista-only, and Oracle Health-only scenarios.

      let(:vista_med_old) do
        OpenStruct.new(
          prescription_name: 'Vista Old Med',
          disp_status: 'Active',
          prescription_source: 'VA',
          dispensed_date: Date.new(2024, 1, 1),
          dispenses: [
            { dispensed_date: Date.new(2024, 2, 15), refill_date: Date.new(2024, 2, 10) }
          ],
          orderable_item: nil
        )
      end

      let(:vista_med_recent) do
        OpenStruct.new(
          prescription_name: 'Vista Recent Med',
          disp_status: 'Active',
          prescription_source: 'VA',
          dispensed_date: Date.new(2024, 1, 1),
          dispenses: [
            { dispensed_date: Date.new(2024, 6, 20), refill_date: Date.new(2024, 6, 15) }
          ],
          orderable_item: nil
        )
      end

      # Oracle Health: dispensed_date is populated from FHIR whenHandedOver by the adapter
      let(:oracle_med_middle) do
        OpenStruct.new(
          prescription_name: 'Oracle Middle Med',
          disp_status: 'Active',
          prescription_source: 'VA',
          dispensed_date: Date.new(2024, 1, 1),
          dispenses: [
            { dispensed_date: Date.new(2024, 4, 10) }
          ],
          orderable_item: nil
        )
      end

      let(:oracle_med_old) do
        OpenStruct.new(
          prescription_name: 'Oracle Old Med',
          disp_status: 'Active',
          prescription_source: 'VA',
          dispensed_date: nil,
          dispenses: [
            { dispensed_date: Date.new(2024, 2, 5) }
          ],
          orderable_item: nil
        )
      end

      let(:oracle_med_recent) do
        OpenStruct.new(
          prescription_name: 'Oracle Recent Med',
          disp_status: 'Active',
          prescription_source: 'VA',
          dispensed_date: nil,
          dispenses: [
            { dispensed_date: Date.new(2024, 5, 25) }
          ],
          orderable_item: nil
        )
      end

      def build_resource(records)
        records_copy = records.dup
        metadata = {}
        double('resource').tap do |r|
          allow(r).to receive_messages(records: records_copy, metadata:)
          allow(r).to receive(:records=) { |new_records| records_copy.replace(new_records) }
          allow(r).to receive(:metadata=) { |new_metadata| metadata.replace(new_metadata) }
        end
      end

      it 'sorts mixed Vista and Oracle Health prescriptions by last filled date descending' do
        mixed_prescriptions = [vista_med_old, oracle_med_middle, vista_med_recent]
        resource = build_resource(mixed_prescriptions)

        result = helper.apply_sorting(resource, 'last-fill-date')

        # Expected order (most recent first):
        # 1. Vista Recent Med - dispensed_date: 2024-06-20
        # 2. Oracle Middle Med - dispensed_date: 2024-04-10
        # 3. Vista Old Med - dispensed_date: 2024-02-15
        sorted_names = result.records.map(&:prescription_name)
        expect(sorted_names).to eq(['Vista Recent Med', 'Oracle Middle Med', 'Vista Old Med'])
      end

      it 'sorts Vista-only prescriptions by dispensed_date descending' do
        vista_only = [vista_med_old, vista_med_recent]
        resource = build_resource(vista_only)

        result = helper.apply_sorting(resource, 'last-fill-date')

        sorted_names = result.records.map(&:prescription_name)
        # Recent (2024-06-20) should come before Old (2024-02-15)
        expect(sorted_names).to eq(['Vista Recent Med', 'Vista Old Med'])
      end

      it 'sorts Oracle Health-only prescriptions by refill_date descending' do
        oracle_only = [oracle_med_old, oracle_med_recent]
        resource = build_resource(oracle_only)

        result = helper.apply_sorting(resource, 'last-fill-date')

        sorted_names = result.records.map(&:prescription_name)
        # Recent (2024-05-25) should come before Old (2024-02-05)
        expect(sorted_names).to eq(['Oracle Recent Med', 'Oracle Old Med'])
      end
    end
  end
end
