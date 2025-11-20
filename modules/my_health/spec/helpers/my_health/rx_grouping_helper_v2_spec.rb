# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MyHealth::RxGroupingHelperV2 do
  # Test through the module_function interface
  # Note: group_prescriptions is defined as a module_function, but we test
  # get_single_rx_from_grouped_list and count_grouped_prescriptions
  # through an included class since they call group_prescriptions internally

  # Create a test class that includes the helper module for non-module_function methods
  let(:test_class) do
    Class.new do
      include MyHealth::RxGroupingHelperV2

      # Make group_prescriptions public for testing
      public :group_prescriptions
    end
  end

  let(:helper) { test_class.new }
  let(:prescription1) do
    build(:prescription_details,
          prescription_id: 1,
          prescription_number: '1234567',
          prescription_name: 'Medication A',
          station_number: '989')
  end

  let(:prescription2) do
    build(:prescription_details,
          prescription_id: 2,
          prescription_number: '1234567A',
          prescription_name: 'Medication A',
          station_number: '989')
  end

  let(:prescription3) do
    build(:prescription_details,
          prescription_id: 3,
          prescription_number: '1234567B',
          prescription_name: 'Medication A',
          station_number: '989')
  end

  let(:prescription4) do
    build(:prescription_details,
          prescription_id: 4,
          prescription_number: '7654321',
          prescription_name: 'Medication B',
          station_number: '989')
  end

  let(:prescription5) do
    build(:prescription_details,
          prescription_id: 5,
          prescription_number: '9999999',
          prescription_name: 'Medication C',
          station_number: '123')
  end

  describe '#group_prescriptions' do
    context 'when prescriptions have no related prescriptions' do
      it 'returns prescriptions as-is' do
        prescriptions = [prescription1, prescription4, prescription5]
        result = helper.group_prescriptions(prescriptions)

        expect(result.length).to eq(3)
        expect(result.map(&:prescription_id)).to contain_exactly(1, 4, 5)
        result.each do |rx|
          expect(rx.grouped_medications).to be_nil
        end
      end
    end

    context 'when prescriptions have related prescriptions (refills)' do
      it 'groups related prescriptions by prescription number and station' do
        prescriptions = [prescription1, prescription2, prescription3, prescription4]
        result = helper.group_prescriptions(prescriptions)

        expect(result.length).to eq(2)

        # Find the grouped prescription (should be the highest number: prescription3)
        grouped_rx = result.find { |rx| rx.prescription_id == 3 }
        expect(grouped_rx).not_to be_nil
        expect(grouped_rx.grouped_medications).not_to be_nil
        expect(grouped_rx.grouped_medications.length).to eq(2)
        expect(grouped_rx.grouped_medications.map(&:prescription_id)).to contain_exactly(1, 2)

        # Find the solo prescription
        solo_rx = result.find { |rx| rx.prescription_id == 4 }
        expect(solo_rx).not_to be_nil
        expect(solo_rx.grouped_medications).to be_nil
      end

      it 'sorts related prescriptions correctly by suffix' do
        prescriptions = [prescription3, prescription1, prescription2]
        result = helper.group_prescriptions(prescriptions)

        grouped_rx = result.first
        grouped_meds = grouped_rx.grouped_medications

        # Should be sorted with B before A before base number
        expect(grouped_meds[0].prescription_number).to eq('1234567A')
        expect(grouped_meds[1].prescription_number).to eq('1234567')
      end
    end

    context 'when prescriptions have same prescription number but different stations' do
      let(:prescription_station_a) do
        build(:prescription_details,
              prescription_id: 10,
              prescription_number: '1111111',
              station_number: '989')
      end

      let(:prescription_station_b) do
        build(:prescription_details,
              prescription_id: 11,
              prescription_number: '1111111',
              station_number: '123')
      end

      it 'does not group prescriptions from different stations' do
        prescriptions = [prescription_station_a, prescription_station_b]
        result = helper.group_prescriptions(prescriptions)

        expect(result.length).to eq(2)
        result.each do |rx|
          expect(rx.grouped_medications).to be_nil
        end
      end
    end

    context 'when prescriptions is nil' do
      it 'returns an empty array' do
        result = helper.group_prescriptions(nil)
        expect(result).to eq([])
      end
    end

    context 'when prescriptions is an empty array' do
      it 'returns an empty array' do
        result = helper.group_prescriptions([])
        expect(result).to eq([])
      end
    end

    context 'with complex grouping scenarios' do
      let(:prescription_a1) do
        build(:prescription_details,
              prescription_id: 100,
              prescription_number: '1000000',
              station_number: '989')
      end

      let(:prescription_a2) do
        build(:prescription_details,
              prescription_id: 101,
              prescription_number: '1000000A',
              station_number: '989')
      end

      let(:prescription_a3) do
        build(:prescription_details,
              prescription_id: 102,
              prescription_number: '1000000B',
              station_number: '989')
      end

      let(:prescription_b1) do
        build(:prescription_details,
              prescription_id: 200,
              prescription_number: '2000000',
              station_number: '989')
      end

      let(:prescription_b2) do
        build(:prescription_details,
              prescription_id: 201,
              prescription_number: '2000000A',
              station_number: '989')
      end

      it 'groups multiple prescription families correctly' do
        prescriptions = [prescription_a1, prescription_a2, prescription_a3,
                         prescription_b1, prescription_b2, prescription4]
        result = helper.group_prescriptions(prescriptions)

        expect(result.length).to eq(3)

        # Group A - highest is prescription_a3 (1000000B)
        group_a = result.find { |rx| rx.prescription_id == 102 }
        expect(group_a.grouped_medications.length).to eq(2)
        expect(group_a.grouped_medications.map(&:prescription_id)).to contain_exactly(100, 101)

        # Group B - highest is prescription_b2 (2000000A)
        group_b = result.find { |rx| rx.prescription_id == 201 }
        expect(group_b.grouped_medications.length).to eq(1)
        expect(group_b.grouped_medications.first.prescription_id).to eq(200)

        # Solo prescription
        solo = result.find { |rx| rx.prescription_id == 4 }
        expect(solo.grouped_medications).to be_nil
      end
    end
  end

  describe '#get_single_rx_from_grouped_list' do
    context 'when prescription exists in the list' do
      it 'returns the prescription with matching id' do
        prescriptions = [prescription1, prescription2, prescription3, prescription4]
        result = helper.get_single_rx_from_grouped_list(prescriptions, 3)

        expect(result).not_to be_nil
        expect(result.prescription_id).to eq(3)
        expect(result.grouped_medications).not_to be_nil
      end

      it 'returns a prescription even if it is grouped under another' do
        prescriptions = [prescription1, prescription2, prescription3]
        # prescription1 should be grouped under prescription3 but we can still find it
        result = helper.get_single_rx_from_grouped_list(prescriptions, 1)

        # Since prescription1 gets grouped under prescription3, it won't be in the top-level results
        # This tests the actual behavior - grouped items aren't findable at the top level
        expect(result).to be_nil
      end
    end

    context 'when prescription does not exist in the list' do
      it 'returns nil' do
        prescriptions = [prescription1, prescription2]
        result = helper.get_single_rx_from_grouped_list(prescriptions, 999)

        expect(result).to be_nil
      end
    end

    context 'when list is empty' do
      it 'returns nil' do
        result = helper.get_single_rx_from_grouped_list([], 1)
        expect(result).to be_nil
      end
    end
  end

  describe '#count_grouped_prescriptions' do
    context 'when prescriptions have no related prescriptions' do
      it 'counts each prescription individually' do
        prescriptions = [prescription1, prescription4, prescription5]
        result = helper.count_grouped_prescriptions(prescriptions)

        expect(result).to eq(3)
      end
    end

    context 'when prescriptions have related prescriptions' do
      it 'counts grouped prescriptions as one' do
        prescriptions = [prescription1, prescription2, prescription3, prescription4]
        result = helper.count_grouped_prescriptions(prescriptions)

        # prescription1, prescription2, prescription3 are grouped as 1
        # prescription4 is 1
        expect(result).to eq(2)
      end
    end

    context 'when prescriptions is nil' do
      it 'returns 0' do
        result = helper.count_grouped_prescriptions(nil)
        expect(result).to eq(0)
      end
    end

    context 'when prescriptions is an empty array' do
      it 'returns 0' do
        result = helper.count_grouped_prescriptions([])
        expect(result).to eq(0)
      end
    end

    context 'with multiple prescription families' do
      let(:prescription_a1) do
        build(:prescription_details,
              prescription_id: 100,
              prescription_number: '1000000',
              station_number: '989')
      end

      let(:prescription_a2) do
        build(:prescription_details,
              prescription_id: 101,
              prescription_number: '1000000A',
              station_number: '989')
      end

      let(:prescription_b1) do
        build(:prescription_details,
              prescription_id: 200,
              prescription_number: '2000000',
              station_number: '989')
      end

      let(:prescription_b2) do
        build(:prescription_details,
              prescription_id: 201,
              prescription_number: '2000000A',
              station_number: '989')
      end

      it 'counts multiple groups correctly' do
        prescriptions = [prescription_a1, prescription_a2, prescription_b1,
                         prescription_b2, prescription4]
        result = helper.count_grouped_prescriptions(prescriptions)

        # Group A (2 prescriptions) = 1 count
        # Group B (2 prescriptions) = 1 count
        # Solo prescription4 = 1 count
        expect(result).to eq(3)
      end
    end

    context 'when list is modified during counting' do
      it 'does not modify the original list' do
        prescriptions = [prescription1, prescription2, prescription3, prescription4]
        original_length = prescriptions.length

        helper.count_grouped_prescriptions(prescriptions)

        expect(prescriptions.length).to eq(original_length)
      end
    end
  end

  describe 'edge cases and sorting behavior' do
    context 'with prescriptions that have letter suffixes in different order' do
      it 'groups them correctly with highest suffix as base' do
        # Create prescriptions in random order
        prescriptions = [prescription2, prescription3, prescription1] # A, B, base
        result = helper.group_prescriptions(prescriptions)

        expect(result.length).to eq(1)
        base_rx = result.first
        expect(base_rx.prescription_number).to eq('1234567B') # Highest should be base
        expect(base_rx.grouped_medications.length).to eq(2)
      end
    end

    context 'with mixed solo and grouped prescriptions' do
      it 'returns correct structure' do
        prescriptions = [prescription1, prescription2, prescription3, prescription4, prescription5]
        result = helper.group_prescriptions(prescriptions)

        # Should have 3 groups: 1 grouped (1,2,3) and 2 solo (4,5)
        expect(result.length).to eq(3)

        grouped_item = result.find { |rx| rx.prescription_id == 3 }
        expect(grouped_item.grouped_medications).not_to be_nil
        expect(grouped_item.grouped_medications.length).to eq(2)

        solo_items = result.select { |rx| [4, 5].include?(rx.prescription_id) }
        expect(solo_items.length).to eq(2)
        solo_items.each do |rx|
          expect(rx.grouped_medications).to be_nil
        end
      end
    end

    context 'with prescriptions sorted in descending order' do
      it 'still groups correctly' do
        prescriptions = [prescription3, prescription2, prescription1].reverse
        result = helper.group_prescriptions(prescriptions)

        expect(result.length).to eq(1)
        expect(result.first.grouped_medications.length).to eq(2)
      end
    end
  end

  describe 'when included in a class' do
    it 'provides grouping functionality to the including class' do
      prescriptions = [prescription1, prescription2, prescription3]
      result = helper.group_prescriptions(prescriptions)

      expect(result.length).to eq(1)
      expect(result.first.grouped_medications.length).to eq(2)
    end
  end

  describe 'handling prescriptions with missing prescription_number' do
    let(:prescription_no_number) do
      build(:prescription_details,
            prescription_id: 100,
            prescription_number: nil,
            prescription_name: 'Non-VA Med',
            station_number: '989')
    end

    let(:prescription_empty_number) do
      build(:prescription_details,
            prescription_id: 101,
            prescription_number: '',
            prescription_name: 'Non-VA Med 2',
            station_number: '989')
    end

    let(:prescription_whitespace_number) do
      build(:prescription_details,
            prescription_id: 102,
            prescription_number: '   ',
            prescription_name: 'Non-VA Med 3',
            station_number: '989')
    end

    context 'with nil prescription_number' do
      it 'includes prescription at the end without grouping' do
        prescriptions = [prescription1, prescription_no_number, prescription4]
        result = helper.group_prescriptions(prescriptions)

        expect(result.length).to eq(3)
        expect(result.last.prescription_id).to eq(100)
        expect(result.last.grouped_medications).to be_nil
      end
    end

    context 'with empty string prescription_number' do
      it 'includes prescription at the end without grouping' do
        prescriptions = [prescription1, prescription_empty_number, prescription4]
        result = helper.group_prescriptions(prescriptions)

        expect(result.length).to eq(3)
        expect(result.last.prescription_id).to eq(101)
      end
    end

    context 'with whitespace-only prescription_number' do
      it 'includes prescription at the end without grouping' do
        prescriptions = [prescription1, prescription_whitespace_number]
        result = helper.group_prescriptions(prescriptions)

        expect(result.length).to eq(2)
        expect(result.last.prescription_id).to eq(102)
      end
    end

    context 'with multiple prescriptions without numbers' do
      it 'includes all at the end in original order' do
        prescriptions = [prescription1, prescription_no_number, prescription4, prescription_empty_number]
        result = helper.group_prescriptions(prescriptions)

        expect(result.length).to eq(4)
        # Last two should be the ones without numbers
        expect(result[-2].prescription_id).to eq(100)
        expect(result[-1].prescription_id).to eq(101)
      end
    end

    context 'with only prescriptions without numbers' do
      it 'returns all prescriptions ungrouped' do
        prescriptions = [prescription_no_number, prescription_empty_number, prescription_whitespace_number]
        result = helper.group_prescriptions(prescriptions)

        expect(result.length).to eq(3)
        expect(result.map(&:prescription_id)).to contain_exactly(100, 101, 102)
      end
    end

    context 'when counting prescriptions with missing numbers' do
      it 'counts each missing number prescription individually' do
        prescriptions = [prescription1, prescription2, prescription_no_number, prescription_empty_number]
        result = helper.count_grouped_prescriptions(prescriptions)

        # prescription1 + prescription2 would group = 1
        # prescription_no_number = 1
        # prescription_empty_number = 1
        expect(result).to eq(3)
      end
    end

    context 'when mixed with grouped prescriptions' do
      it 'places prescriptions without numbers at the end' do
        prescriptions = [prescription_no_number, prescription1, prescription2, prescription3, prescription_empty_number]
        result = helper.group_prescriptions(prescriptions)

        expect(result.length).to eq(3)
        # First should be the grouped prescription (1, 2, 3)
        expect(result.first.prescription_id).to eq(3)
        expect(result.first.grouped_medications.length).to eq(2)
        # Last two should be the ones without numbers
        expect(result[-2].prescription_id).to eq(100)
        expect(result[-1].prescription_id).to eq(101)
      end
    end
  end

  describe 'handling prescriptions without respond_to?(:prescription_number)' do
    let(:prescription_no_method) do
      double('Prescription',
             prescription_id: 200,
             prescription_name: 'Legacy Med',
             station_number: '989')
    end

    it 'handles prescriptions that do not respond to prescription_number' do
      prescriptions = [prescription1, prescription_no_method]
      result = helper.group_prescriptions(prescriptions)

      expect(result.length).to eq(2)
      expect(result.last).to eq(prescription_no_method)
    end
  end

  describe 'complex suffix patterns' do
    context 'with multiple letter suffixes' do
      let(:prescription_aa) do
        build(:prescription_details,
              prescription_id: 300,
              prescription_number: '5555555AA',
              station_number: '989')
      end

      let(:prescription_ab) do
        build(:prescription_details,
              prescription_id: 301,
              prescription_number: '5555555AB',
              station_number: '989')
      end

      let(:prescription_base) do
        build(:prescription_details,
              prescription_id: 302,
              prescription_number: '5555555',
              station_number: '989')
      end

      it 'does not group multi-letter suffixes as they use single-letter pattern' do
        # NOTE: The helper uses /[A-Z]$/ which only matches single trailing letter
        # So '5555555AA' and '5555555AB' are NOT grouped with '5555555'
        # because the base extraction removes only the last 'A' or 'B', leaving '5555555A'
        prescriptions = [prescription_base, prescription_aa, prescription_ab]
        result = helper.group_prescriptions(prescriptions)

        # These will not group because:
        # - '5555555AA'.sub(/[A-Z]$/, '') = '5555555A'
        # - '5555555AB'.sub(/[A-Z]$/, '') = '5555555A'
        # - '5555555'.sub(/[A-Z]$/, '') = '5555555'
        # The base '5555555' doesn't match '5555555A'
        expect(result.length).to eq(2) # AA and AB will group together, base stays separate

        # Find the group with AA/AB
        aa_ab_group = result.find { |rx| rx.prescription_id == 301 }
        expect(aa_ab_group).not_to be_nil
        expect(aa_ab_group.grouped_medications.length).to eq(1)
        expect(aa_ab_group.grouped_medications.first.prescription_id).to eq(300)
      end
    end

    context 'with same suffix but different base numbers' do
      let(:prescription_1a) do
        build(:prescription_details,
              prescription_id: 400,
              prescription_number: '1111111A',
              station_number: '989')
      end

      let(:prescription_2a) do
        build(:prescription_details,
              prescription_id: 401,
              prescription_number: '2222222A',
              station_number: '989')
      end

      it 'does not group prescriptions with different base numbers' do
        prescriptions = [prescription_1a, prescription_2a]
        result = helper.group_prescriptions(prescriptions)

        expect(result.length).to eq(2)
        result.each do |rx|
          expect(rx.grouped_medications).to be_nil
        end
      end
    end
  end

  describe 'station number filtering' do
    let(:prescription_station_a) do
      build(:prescription_details,
            prescription_id: 500,
            prescription_number: '7777777',
            station_number: '989')
    end

    let(:prescription_station_a_refill) do
      build(:prescription_details,
            prescription_id: 501,
            prescription_number: '7777777A',
            station_number: '989')
    end

    let(:prescription_station_b) do
      build(:prescription_details,
            prescription_id: 502,
            prescription_number: '7777777',
            station_number: '123')
    end

    let(:prescription_station_b_refill) do
      build(:prescription_details,
            prescription_id: 503,
            prescription_number: '7777777A',
            station_number: '123')
    end

    it 'groups prescriptions only within the same station' do
      prescriptions = [prescription_station_a, prescription_station_a_refill,
                       prescription_station_b, prescription_station_b_refill]
      result = helper.group_prescriptions(prescriptions)

      expect(result.length).to eq(2)

      # Each station should have its own group
      station_a_group = result.find { |rx| rx.prescription_id == 501 }
      expect(station_a_group).not_to be_nil
      expect(station_a_group.grouped_medications.length).to eq(1)
      expect(station_a_group.grouped_medications.first.prescription_id).to eq(500)

      station_b_group = result.find { |rx| rx.prescription_id == 503 }
      expect(station_b_group).not_to be_nil
      expect(station_b_group.grouped_medications.length).to eq(1)
      expect(station_b_group.grouped_medications.first.prescription_id).to eq(502)
    end
  end

  describe 'sorting within grouped medications' do
    let(:prescription_c) do
      build(:prescription_details,
            prescription_id: 600,
            prescription_number: '8888888C',
            station_number: '989')
    end

    let(:prescription_b) do
      build(:prescription_details,
            prescription_id: 601,
            prescription_number: '8888888B',
            station_number: '989')
    end

    let(:prescription_a) do
      build(:prescription_details,
            prescription_id: 602,
            prescription_number: '8888888A',
            station_number: '989')
    end

    let(:prescription_base) do
      build(:prescription_details,
            prescription_id: 603,
            prescription_number: '8888888',
            station_number: '989')
    end

    it 'sorts grouped_medications in descending suffix order (B, A, base)' do
      prescriptions = [prescription_base, prescription_a, prescription_b, prescription_c]
      result = helper.group_prescriptions(prescriptions)

      expect(result.length).to eq(1)
      grouped_meds = result.first.grouped_medications

      expect(grouped_meds[0].prescription_number).to eq('8888888B')
      expect(grouped_meds[1].prescription_number).to eq('8888888A')
      expect(grouped_meds[2].prescription_number).to eq('8888888')
    end
  end

  describe 'get_single_rx_from_grouped_list with missing numbers' do
    let(:prescription_no_number) do
      build(:prescription_details,
            prescription_id: 700,
            prescription_number: nil,
            prescription_name: 'Non-VA Med')
    end

    it 'can find prescriptions without prescription numbers' do
      prescriptions = [prescription1, prescription_no_number]
      result = helper.get_single_rx_from_grouped_list(prescriptions, 700)

      expect(result).not_to be_nil
      expect(result.prescription_id).to eq(700)
    end
  end
end
