# frozen_string_literal: true

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

      def initialize(args)
        @name = args[:name]
        @email = args[:email]

        raise ArgumentError, 'name and email are required' if @name.nil? || @email.nil?
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
        expect(described_class.cast(name, String, value)).to eq('123')
      end
    end

    context 'when casting a String to Integer' do
      let(:value) { '123' }

      it 'raises an error (cannot cast String to Integer)' do
        expect(described_class.cast(name, Integer, value)).to eq(123)
      end
    end

    context 'when casting a Hash to User (dynamic class)' do
      let(:value) { { name: 'John Doe', email: 'john@example.com' } }
      let(:expected_user) { user_class.new(name: 'John Doe', email: 'john@example.com') }

      it 'casts Hash to User' do
        expect(described_class.cast(name, user_class, [value], array: true)).to eq([expected_user])
      end
    end

    context 'when casting a User to User (dynamic class)' do
      let(:user) { user_class.new(name: 'John Doe', email: 'john@example.com') }

      it 'returns the same User object' do
        expect(described_class.cast(name, user_class, [user], array: true)).to eq([user])
      end
    end

    context 'when casting a String to UTCTime' do
      let(:value) { '2024-12-19T12:34:56+04:00' }

      it 'casts String to a Time object in UTC' do
        expected_time = Time.parse(value).utc
        expect(described_class.cast(name, Vets::Type::UTCTime, value)).to eq(expected_time)
      end
    end

    context 'when casting a Hash to Hash' do
      let(:value) { { key: 'value' } }

      it 'returns the same Hash' do
        expect(described_class.cast(name, Hash, value)).to eq(value)
      end
    end

    context 'when the array is empty' do
      let(:value) { [] }

      it 'returns an empty array' do
        expect(described_class.cast(name, String, value, array: true)).to eq([])
      end
    end

    context 'when the value is nil' do
      let(:value) { nil }

      it 'returns nil' do
        expect(described_class.cast(name, String, value)).to be_nil
      end
    end

    context 'when casting an Array of Strings' do
      let(:value) { %w[apple banana] }

      it 'returns the same array of Strings' do
        expect(described_class.cast(name, String, value, array: true)).to eq(value)
      end
    end

    context 'when casting an Array contains nil values' do
      let(:value) { [nil, 'test', nil] }

      it 'raise a TypeError' do
        expect do
          described_class.cast(name, String, value, array: true)
        end.to raise_error(TypeError, "All elements of #{name} must be of type String")
      end
    end

    context 'when casting a String to Bool' do
      it 'casts a non-falsey, non-empty String to a true Bool' do
        expect(described_class.cast(name, Bool, 'test')).to be_truthy
      end

      it 'casts "falsey" string to a false Bool' do
        expect(described_class.cast(name, Bool, 'false')).to be_falsey
      end

      it 'casts a empty String to nil' do
        expect(described_class.cast(name, Bool, nil)).to be_nil
      end
    end

    context 'when casting an Integer to Bool' do
      it 'casts a non-zero Integer to a true Bool' do
        expect(described_class.cast(name, Bool, 1)).to be_truthy
      end

      it 'casts zero (Integer) to a false Bool' do
        expect(described_class.cast(name, Bool, 0)).to be_falsey
      end
    end
  end

  describe '#setter_value' do
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
