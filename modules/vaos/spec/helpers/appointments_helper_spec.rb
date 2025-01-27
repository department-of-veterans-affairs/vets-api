# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VAOS::AppointmentsHelper do
  describe '#cerner?' do
    it 'raises an ArgumentError if appt is nil' do
      expect { subject.cerner?(nil) }.to raise_error(ArgumentError, 'Appointment cannot be nil')
    end

    it 'returns true when the appointment is cerner' do
      appt = {
        identifier: [
          {
            system: 'urn:va.gov:masv2:cerner:appointment',
            value: 'Appointment/52499028'
          }
        ]
      }

      expect(subject.cerner?(appt)).to be(true)
    end

    it 'returns false when the appointment is not cerner' do
      appt = {
        identifier: [
          {
            system: 'someother system',
            value: 'appointment/1'
          }
        ]
      }

      expect(subject.cerner?(appt)).to be(false)
    end

    it 'returns true when at least one identifier is cerner' do
      appt = {
        identifier: [
          {
            system: 'someother system',
            value: 'appointment/1'
          },
          {
            system: 'urn:va.gov:masv2:cerner:appointment',
            value: 'Appointment/52499028'
          }
        ]
      }

      expect(subject.cerner?(appt)).to be(true)
    end

    it 'returns false when the appointment does not contain identifier(s)' do
      appt = {}

      expect(subject.cerner?(appt)).to be(false)
    end
  end

  describe 'extract_all_values' do
    context 'when processing an array, hash, or openstruct' do
      let(:array1) { ['a', 'b', 'c', %w[100 200 300]] }

      let(:hash1) { { a: '100', b: '200', c: '300' } }

      let(:os1) do
        OpenStruct.new({ 'a' => '100', 'b' => '200', 'c' => '300', 'd' => 400 })
      end

      it 'returns an array of values from an array' do
        expect(subject.extract_all_values(array1)).to eq(%w[a b c 100 200 300])
      end

      it 'returns an array of values from a hash' do
        expect(subject.extract_all_values(hash1)).to eq(%w[100 200 300])
      end

      it 'returns an array of values from a simple openstruct' do
        expect(subject.extract_all_values(os1)).to eq(['100', '200', '300', 400])
      end

      it 'returns an array of values from a nested openstruct' do
        struct = OpenStruct.new(
          {
            single_value: '1',
            nested_values: [
              '2',
              %w[3 4],
              { key: %w[5 6] },
              { key: { k1: '7', k2: '8' } }
            ]
          }
        )
        result = %w[1 2 3 4 5 6 7 8]
        expect(subject.extract_all_values(struct)).to eq(result)
      end
    end

    context 'when processing input that is not an array, hash, or openstruct' do
      it 'returns input object in an array' do
        expect(subject.extract_all_values('Simple String Input')).to eq(['Simple String Input'])
      end

      it 'returns input object in an array (nil)' do
        expect(subject.extract_all_values(nil)).to eq([nil])
      end
    end
  end

  describe 'contains_substring?' do
    context 'when checking an input array that contains a given substring' do
      it 'returns true' do
        expect(subject.contains_substring?(['given string', 'another string', 100], 'given string')).to be(true)
      end
    end

    context 'when checking an input array that does not contain a given substring' do
      it 'returns false' do
        expect(subject.contains_substring?(['given string', 'another string', 100],
                                           'different string')).to be(false)
      end
    end

    context 'when checking a non-array and a string' do
      it 'returns false' do
        expect(subject.contains_substring?('given string', 'given string')).to be(false)
      end
    end

    context 'when checking nil and a string' do
      it 'returns false' do
        expect(subject.contains_substring?(nil, 'some string')).to be(false)
      end
    end

    context 'when checking an array and a non-string' do
      it 'returns false' do
        expect(subject.contains_substring?(['given string', 'another string', 100], 100)).to be(false)
      end
    end

    context 'when the input array contains nil' do
      it 'returns false' do
        expect(subject.contains_substring?([nil], 'some string')).to be(false)
      end
    end

    context 'when the input array is empty' do
      it 'returns false' do
        expect(subject.contains_substring?([], 'some string')).to be(false)
      end
    end
  end
end
