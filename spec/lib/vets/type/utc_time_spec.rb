# frozen_string_literal: true

require 'rails_helper'
require 'vets/type/utc_time'

RSpec.describe Vets::Type::UTCTime do
  let(:name) { 'test_utc_time' }
  let(:klass) { Time }
  let(:utc_time_instance) { described_class.new(name, klass) }

  describe '#cast' do
    context 'when value is nil' do
      it 'returns nil' do
        expect(utc_time_instance.cast(nil)).to be_nil
      end
    end

    context 'when value is a valid Time string' do
      let(:valid_time_string) { '2024-12-19 12:34:56' }

      it 'returns a UTC Time object' do
        expected_time = Time.parse(valid_time_string).utc
        expect(utc_time_instance.cast(valid_time_string)).to eq(expected_time)
      end
    end

    context 'when value is an invalid Time string' do
      let(:invalid_time_string) { 'invalid-time' }

      it 'raises a TypeError with the correct message' do
        expect do
          utc_time_instance.cast(invalid_time_string)
        end.to raise_error(TypeError, "#{name} is not Time parseable")
      end
    end

    context 'when value is a valid Time object' do
      let(:valid_time_object) { Time.zone.now }

      it 'returns the Time object in UTC' do
        expect(utc_time_instance.cast(valid_time_object.round)).to eq(valid_time_object.utc.round)
      end
    end
  end
end
