# frozen_string_literal: true

require 'rails_helper'
require 'vets/type/date_time_string'

RSpec.describe Vets::Type::DateTimeString do
  let(:name) { 'test_datetime' }
  let(:klass) { String }
  let(:datetime_instance) { described_class.new(name, klass) }

  describe '#cast' do
    context 'when value is nil' do
      it 'returns nil' do
        expect(datetime_instance.cast(nil)).to be_nil
      end
    end

    context 'when value is a valid datetime string' do
      let(:valid_datetime) { '2024-12-19T12:34:56Z' }

      it 'returns the ISO8601 formatted datetime string' do
        expect(datetime_instance.cast(valid_datetime)).to eq(Time.parse(valid_datetime).iso8601)
      end
    end

    context 'when value is an invalid datetime string' do
      let(:invalid_datetime) { 'invalid-datetime' }

      it 'raises a TypeError with the correct message' do
        expect do
          datetime_instance.cast(invalid_datetime)
        end.to raise_error(TypeError, "#{name} is not Time parseable")
      end
    end
  end
end
