# frozen_string_literal: true

require 'rails_helper'
require 'vets/value'
require 'vets/attributes'
require 'vets/model' # temporarily needed for Boolean

RSpec.describe Vets::Attributes::Value do
  describe '.cast' do
    context 'when casting a single value' do
      it 'returns the coerced value for a valid class' do
        result = described_class.cast(:test_name, String, 'test_value')
        expect(result).to eq('test_value')
      end

      it 'raises a TypeError for invalid types' do
        expect do
          described_class.cast(:test_name, Integer, 'not_an_integer')
        end.to raise_error(TypeError, 'test_name must be a Integer')
      end
    end

    context 'when handling Boolean values' do
      it 'casts values to Boolean' do
        result = described_class.cast(:boolean_name, Boolean, 'true')
        expect(result).to be true
      end

      it 'raises a TypeError for non-boolean values' do
        expect do
          described_class.cast(:boolean_name, Boolean, 'not_a_boolean')
        end.to raise_error(TypeError, 'boolean_name must be a Boolean')
      end
    end

    context 'when casting array values' do
      let(:array_class) { DoubleClass } # Assume DoubleClass is defined elsewhere

      it 'raises TypeError if value is not an Array' do
        expect do
          described_class.cast(:test_array, array_class, 'not_an_array', array: true)
        end.to raise_error(TypeError, 'test_array must be an Array')
      end

      it 'raises TypeError if elements are of incorrect type' do
        expect do
          described_class.cast(:test_array, array_class, %w[correct_type wrong_type], array: true)
        end.to raise_error(TypeError, "All elements of test_array must be of type #{array_class}")
      end

      it 'returns an array of coerced values for valid inputs' do
        result = described_class.cast(:test_array, array_class, [{ attr: 'value' }, { attr: 'value2' }], array: true)
        expect(result).to all(be_an(array_class))
      end
    end
  end

  describe '#setter_value' do
    let(:value_instance) { described_class.new(:test_name, String) }

    it 'validates and sets the value correctly' do
      result = value_instance.setter_value('valid_value')
      expect(result).to eq('valid_value')
    end

    it 'raises an error for an invalid value type' do
      expect do
        value_instance.setter_value(123)
      end.to raise_error(TypeError, 'test_name must be a String')
    end
  end

  describe '#validate_array' do
    let(:value_instance) { described_class.new(:test_array, String, array: true) }

    it 'raises an error if value is not an array' do
      expect do
        value_instance.send(:validate_array, 'not_an_array')
      end.to raise_error(TypeError, 'test_array must be an Array')
    end

    it 'raises an error if elements are of incorrect type' do
      expect do
        value_instance.send(:validate_array, ['valid_string', 123])
      end.to raise_error(TypeError, 'All elements of test_array must be of type String')
    end

    it 'successfully validates an array of valid items' do
      expect do
        value_instance.send(:validate_array, %w[valid_string another_valid_string])
      end.not_to raise_error
    end
  end
end

# Example DoubleClass for array testing
class DoubleClass
  attr_reader :attr

  def initialize(attrs)
    @attr = attrs[:attr]
  end
end
