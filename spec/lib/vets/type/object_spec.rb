# frozen_string_literal: true

require 'rails_helper'
require 'vets/type/object'

RSpec.describe Vets::Type::Object do
  let(:name) { 'test_object' }
  let(:klass) do
    Class.new do
      attr_reader :attributes

      def initialize(attributes = {})
        @attributes = attributes
      end

      def ==(other)
        other.is_a?(self.class) && other.attributes == attributes
      end
    end
  end
  let(:object_instance) { described_class.new(name, klass) }

  describe '#cast' do
    context 'when value is nil' do
      it 'returns nil' do
        expect(object_instance.cast(nil)).to be_nil
      end
    end

    context 'when value is a Hash' do
      let(:valid_hash) { { key: 'value' } }

      it 'returns an instance of klass initialized with the hash' do
        result = object_instance.cast(valid_hash)
        expect(result).to be_a(klass)
        expect(result.attributes).to eq(valid_hash)
      end
    end

    context 'when value is already an instance of klass' do
      let(:instance_of_klass) { klass.new(key: 'value') }

      it 'returns the same instance' do
        expect(object_instance.cast(instance_of_klass)).to eq(instance_of_klass)
      end
    end

    context 'when value is neither a Hash nor an instance of klass' do
      let(:invalid_value) { 'invalid_value' }

      it 'raises a TypeError with the correct message' do
        expect do
          object_instance.cast(invalid_value)
        end.to raise_error(TypeError, "#{name} must be a Hash or an instance of #{klass}")
      end
    end
  end
end
