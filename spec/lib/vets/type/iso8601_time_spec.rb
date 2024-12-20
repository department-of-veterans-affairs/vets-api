# frozen_string_literal: true

require 'rails_helper'
require 'vets/type/iso8601_time'

RSpec.describe Vets::Type::ISO8601Time do
  let(:name) { 'test_iso8601_time' }
  let(:klass) { String }
  let(:iso8601_instance) { described_class.new(name, klass) }

  describe '#cast' do
    context 'when value is nil' do
      it 'returns nil' do
        expect(iso8601_instance.cast(nil)).to be_nil
      end
    end

    context 'when value is a valid ISO8601 string' do
      let(:valid_iso8601) { '2024-12-19T12:34:56+00:00' }

      it 'returns a Time object' do
        expect(iso8601_instance.cast(valid_iso8601)).to eq(Time.iso8601(valid_iso8601))
      end
    end

    context 'when value is an invalid ISO8601 string' do
      let(:invalid_iso8601) { 'invalid-iso8601' }

      it 'raises a TypeError with the correct message' do
        expect do
          iso8601_instance.cast(invalid_iso8601)
        end.to raise_error(TypeError, "#{name} is not iso8601")
      end
    end
  end
end
