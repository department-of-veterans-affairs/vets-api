require 'rails_helper'
require 'vets/attributes/value'
require 'vets/type/primitive'
require 'vets/type/object'
require 'vets/type/utc_time'
require 'vets/type/hash'

RSpec.describe Vets::Attributes::Value do
  let(:user_class) do
    Class.new do
      attr_accessor :name, :email

      def initialize(name:, email:)
        raise ArgumentError, "name is required" if name.nil? || name.empty?
        raise ArgumentError, "email is required" if email.nil? || email.empty?

        @name = name
        @email = email
      end

      def ==(other)
        other.is_a?(self.class) && other.name == @name && other.email == @email
      end
    end
  end

  let(:name) { 'test_name' }

  describe '.cast' do
    context 'when casting an Integer to String' do
      let(:value) { 123 }

      it 'casts Integer to String' do
        expect(Vets::Attributes::Value.cast(name, String, value)).to eq('123')
      end
    end

    context 'when casting a String to Integer' do
      let(:value) { '123' }

      it 'raises an error (cannot cast String to Integer)' do
        expect { Vets::Attributes::Value.cast(name, Integer, value) }.to raise_error(TypeError)
      end
    end

    context 'when casting a Hash to User (dynamic class)' do
      let(:value) { { name: 'John Doe', email: 'john@example.com' } }
      let(:expected_user) { user_class.new(name: 'John Doe', email: 'john@example.com') }

      it 'casts Hash to User' do
        user_element_type = Vets::Type::Object.new(name, user_class)
        array_instance = Vets::Type::Array.new(name, Array, user_element_type)
        expect(array_instance.cast([value])).to eq([expected_user])
      end
    end

    context 'when casting a User to User (dynamic class)' do
      let(:user) { user_class.new(name: 'John Doe', email: 'john@example.com') }

      it 'returns the same User object' do
        expect(Vets::Attributes::Value.cast(name, user_class, user)).to eq(user)
      end
    end

    context 'when casting a String to UTCTime' do
      let(:value) { '2024-12-19T12:34:56+04:00' }

      it 'casts String to a Time object in UTC' do
        expected_time = Time.parse(value).utc
        expect(Vets::Attributes::Value.cast(name, Time, value)).to eq(expected_time)
      end
    end

    context 'when casting a Hash to Hash' do
      let(:value) { { key: 'value' } }

      it 'returns the same Hash' do
        expect(Vets::Attributes::Value.cast(name, Hash, value)).to eq(value)
      end
    end

    context 'when the array is empty' do
      let(:value) { [] }

      it 'returns an empty array' do
        array_element_type = Vets::Type::Primitive.new(name, String)
        array_instance = Vets::Type::Array.new(name, Array, array_element_type)
        expect(array_instance.cast(value)).to eq([])
      end
    end

    context 'when the value is nil' do
      let(:value) { nil }

      it 'returns nil' do
        expect(Vets::Attributes::Value.cast(name, String, value)).to be_nil
      end
    end

    context 'when casting an Array of Strings' do
      let(:value) { ['apple', 'banana'] }

      it 'returns the same array of Strings' do
        array_element_type = Vets::Type::Primitive.new(name, String)
        array_instance = Vets::Type::Array.new(name, Array, array_element_type)
        expect(array_instance.cast(value)).to eq(value)
      end
    end

    context 'when value is an Integer' do
      it 'casts Integer to String' do
        attribute_value = described_class.new(:test_name, String)
        setter_value = attribute_value.setter_value(123)
        expect(setter_value).to eq('123')
      end
    end

    context 'when value is a String' do
      it 'raises TypeError when casting a String to Integer' do
        attribute_value = described_class.new(:test_name, Integer)
        expect { attribute_value.setter_value('test') }.to raise_error(TypeError)
      end
    end

    context 'when value is an Array' do
      context 'when array is empty' do
        it 'returns an empty array' do
          attribute_value = described_class.new(:test_name, String, array: true)
          setter_value = attribute_value.setter_value([])
          expect(setter_value).to eq([])
        end
      end

      context 'when array contains nil values' do
        it 'casts nil elements correctly' do
          attribute_value = described_class.new(:test_name, String, array: true)
          setter_value = attribute_value.setter_value([nil, 'test', nil])
          expect(setter_value).to eq([nil, 'test', nil])
        end
      end
    end

    context 'when value is a String and klass is UTCTime' do
      it 'casts a String to a Time object in UTC' do
        value = '2024-12-19T12:34:56+04:00'
        attribute_value = described_class.new(:test_name, Vets::Type::UTCTime)
        setter_value = attribute_value.setter_value(value)
        expect(setter_value).to eq(Time.parse(value).utc)
      end
    end

    context 'when value is a non-castable type' do
      it 'raises TypeError when casting an uncoercible value' do
        attribute_value = described_class.new(:test_name, DateTime)
        expect { attribute_value.setter_value('invalid-date') }.to raise_error(TypeError, 'test_name could not be parsed into a DateTime')
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
  end

  describe '#setter_value'
    context 'when value is an Integer and klass is a String' do
      it 'casts using Vets::Type::Primitive' do
        attribute_value = described_class.new(:test_name, String)
        setter_value = attribute_value.setter_value(123)
        expect(setter_value).to eq('123')
      end
    end

    context 'when value is a String and klass is Vets::Type::UTCTime' do
      it 'casts using Vets::Type::UTCTime' do
        value = '2024-12-19T12:34:56+04:00'
        attribute_value = described_class.new(:test_name, Vets::Type::UTCTime)
        setter_value = attribute_value.setter_value(value)
        expect(setter_value).to eq(Time.parse(value).utc)
      end
    end
  end
end
