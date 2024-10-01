# frozen_string_literal: true

require 'rails_helper'
require 'vets/attributes/value'
require 'vets/attributes'
require 'vets/model' # temporarily needed for Bool

class FakeClass
  attr_reader :attr

  def initialize(attrs)
    @attr = attrs[:attr]
  end
end

RSpec.describe Vets::Attributes::Value do
  describe '.cast' do
    it 'returns a value for a valid type' do
      result = described_class.cast(:test_name, String, 'test_value')
      expect(result).to eq('test_value')
    end

    it 'raises a TypeError for an invalid type' do
      expect do
        described_class.cast(:test_name, Integer, 'not_an_integer')
      end.to raise_error(TypeError, 'test_name must be a Integer')
    end
  end

  describe '#setter_value' do
    context 'when value is a scalar type (e.g., Integer or String)' do
      it 'returns a value for a valid type' do
        attribute_value = described_class.new(:test_name, Bool)
        setter_value = attribute_value.setter_value('test_value')
        expect(setter_value).to be_truthy
      end
    end

    context 'when value is a Bool' do
      it 'coerces a non-falsey, non-empty String to a true Bool' do
        attribute_value = described_class.new(:test_name, Bool)
        setter_value = attribute_value.setter_value('test')
        expect(setter_value).to be_truthy
      end

      it 'casts 0 (Integer) to a false Bool' do
        attribute_value = described_class.new(:test_name, Bool)
        setter_value = attribute_value.setter_value(0)
        expect(setter_value).to be_falsey
      end

      it 'casts "falsey" string to a false Bool' do
        attribute_value = described_class.new(:test_name, Bool)
        setter_value = attribute_value.setter_value('f')
        expect(setter_value).to be_falsey
      end

      it 'coerces a empty String to nil' do
        attribute_value = described_class.new(:test_name, Bool)
        setter_value = attribute_value.setter_value('')
        expect(setter_value).to be_nil
      end
    end

    context 'when value is a complex Object' do
      it 'returns the same complex Object when' do
        attribute_value = described_class.new(:test_name, FakeClass)
        double_class = FakeClass.new(attr: 'Steven')
        setter_value = attribute_value.setter_value(double_class)
        expect(setter_value).to eq(double_class)
      end
    end

    context 'when klass is DateTime' do
      context 'when value is a parseable string' do
        it 'returns a DateTime' do
          value = '2024-01-01T12:00:00+00:00'
          attribute_value = described_class.new(:test_name, DateTime)
          setter_value = attribute_value.setter_value(value)
          expect(setter_value).to eq(DateTime.parse(value).to_s)
        end
      end

      context 'when value is a non-parseable string' do
        it 'raises an TypeError' do
          expect do
            attribute_value = described_class.new(:test_name, DateTime)
            attribute_value.setter_value('bad-time')
          end.to raise_error(TypeError, 'test_name could not be parsed into a DateTime')
        end
      end
    end

    context 'when value is a Hash' do
      context 'when klass is a Hash' do
        it 'returns a complex Object with given attributes' do
          attribute_value = described_class.new(:test_name, FakeClass)
          hash_params = { attr: 'Steven' }
          setter_value = attribute_value.setter_value(hash_params)
          expect(setter_value.class).to eq(FakeClass)
          expect(setter_value.attr).to eq(hash_params[:attr])
        end
      end

      context 'when klass is not a Hash' do
        it 'returns a complex Object with given attributes' do
          attribute_value = described_class.new(:test_name, Hash)
          hash_params = { attr: 'Steven' }
          setter_value = attribute_value.setter_value(hash_params)
          expect(setter_value.class).to eq(Hash)
          expect(setter_value[:attr]).to eq(hash_params[:attr])
        end
      end
    end

    context 'when value is an Array' do
      context 'when elements of value are hashes' do
        it 'coerces elements to klass' do
          attribute_value = described_class.new(:test_array, FakeClass, array: true)
          setter_value = attribute_value.setter_value([{ attr: 'value' }, { attr: 'value2' }])
          expect(setter_value).to all(be_an(FakeClass))
          expect(setter_value.first.attr).to eq('value')
        end
      end

      context 'when elements of value are complex Object' do
        it 'returns the same array' do
          attribute_value = described_class.new(:test_array, FakeClass, array: true)
          double1 = FakeClass.new(attr: 'value')
          double2 = FakeClass.new(attr: 'value1')
          setter_value = attribute_value.setter_value([double1, double2])
          expect(setter_value).to all(be_an(FakeClass))
          expect(setter_value.first.attr).to eq('value')
        end
      end

      it 'raises TypeError if value is not an Array' do
        expect do
          attribute_value = described_class.new(:test_array, FakeClass, array: true)
          attribute_value.setter_value('not_an_array')
        end.to raise_error(TypeError, 'test_array must be an Array')
      end

      it 'raises TypeError if elements are of incorrect type' do
        expect do
          attribute_value = described_class.new(:test_array, FakeClass, array: true)
          attribute_value.setter_value(%w[wrong_type also_wrong_type])
        end.to raise_error(TypeError, "All elements of test_array must be of type #{FakeClass}")
      end
    end
  end
end
