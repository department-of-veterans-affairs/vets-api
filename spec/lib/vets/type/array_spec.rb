require 'rails_helper'
require 'vets/type/array'

RSpec.describe Vets::Type::Array do
  let(:name) { 'test_array' }
  let(:klass) { String }

  # Test with a primitive element type (String)
  let(:string_element_type) { Vets::Type::Primitive.new('String', String) }
  let(:array_instance_with_string) { described_class.new(name, klass, string_element_type) }

  # Test with a custom object element type (using Hash for simplicity)
  let(:hash_element_type) { Vets::Type::Object.new('Hash', Hash) }
  let(:array_instance_with_hash) { described_class.new(name, klass, hash_element_type) }

  let(:utc_time_element_type) { Vets::Type::UTCTime.new('UTCTime', Time) }
  let(:array_instance_with_utc_time) { described_class.new(name, klass, utc_time_element_type) }

  let(:user_class) do
    Class.new do
      attr_accessor :name, :email

      def initialize(name:, email:)

        raise ArgumentError, "name and email Are required" if name.nil? || email.nil?

        @name = name
        @email = email
      end

      def ==(other)
        other.is_a?(self.class) && other.name == @name && other.email == @email
      end
    end
  end

  # Test with Vets::Type::Object element type (casting hashes to User objects)
  let(:user_element_type) { Vets::Type::Object.new('User', user_class) }
  let(:array_instance_with_user) { described_class.new(name, klass, user_element_type) }


  describe '#cast' do
    context 'when value is nil' do
      it 'returns nil' do
        expect(array_instance_with_string.cast(nil)).to be_nil
      end
    end

    context 'when value is a valid array of strings' do
      let(:valid_string_array) { ['hello', 'world'] }

      it 'returns an array of strings' do
        expect(array_instance_with_string.cast(valid_string_array)).to eq(['hello', 'world'])
      end
    end

    context 'when value is a valid array of integers' do
      let(:valid_integer_array) { [123, 456] }

      it 'casts integers to strings' do
        expect(array_instance_with_string.cast(valid_integer_array)).to eq(['123', '456'])
      end
    end

    context 'when value is a valid array of Time objects' do
      let(:valid_time_array) { [Time.new(2024, 12, 19, 12, 34, 56), Time.new(2024, 12, 20, 12, 34, 56)] }

      it 'casts Time objects to strings' do
        expect(array_instance_with_string.cast(valid_time_array)).to eq([valid_time_array[0].to_s, valid_time_array[1].to_s])
      end
    end

    context 'when value is a valid array of hashes' do
      let(:valid_hash_array) { [{ key: 'value' }, { key: 'another_value' }] }

      it 'returns an array of objects' do
        expected_result = valid_hash_array.map { |item| Hash.new('Hash', item.class).cast(item) }
        expect(array_instance_with_hash.cast(valid_hash_array)).to eq(expected_result)
      end
    end

    context 'when value is a valid array of UTCTime objects (with +04:00 offset)' do
      let(:valid_time_array) { ['2024-12-19T12:34:56+04:00', '2024-12-20T12:34:56+04:00'] }
      let(:expected_utc_time_array) { valid_utc_time_array.map { |item| Time.parse(item).utc } }

      it 'casts valid time strings with a +04:00 offset into Time objects' do
        expect(array_instance_with_utc_time.cast(valid_utc_time_array)).to eq(expected_utc_time_array)
      end
    end

    context 'when value is not an array' do
      let(:invalid_value) { 'string' }

      it 'raises a TypeError with the correct message' do
        expect {
          array_instance_with_string.cast(invalid_value)
        }.to raise_error(TypeError, "#{name} must be an Array")
      end
    end

    context 'when value contains elements of different types' do
      let(:mixed_value_array) { ['hello', 123, Time.now] }

      it 'casts non-string elements (integers and Time) to strings' do
        expect(array_instance_with_string.cast(mixed_value_array)).to eq(['hello', '123', Time.now.to_s])
      end
    end

    context 'when value contains elements of inconsistent types after casting' do
      let(:invalid_element_value) { ['hello', 123, Time.now, Object.new] }

      it 'raises a TypeError' do
        expect {
          array_instance_with_string.cast(invalid_element_value)
        }.to raise_error(TypeError, "#{name} must be of type String")
      end
    end

    context 'when value is a valid array of hashes that can be cast into User objects' do
      let(:valid_user_array) do
        [
          { name: 'John Doe', email: 'john@example.com' },
          { name: 'Jane Smith', email: 'jane@example.com' }
        ]
      end
      let(:expected_user_array) do
        valid_user_array.map { |data| user_class.new(data) }
      end

      it 'casts the hashes into User objects' do
        expect(array_instance_with_user.cast(valid_user_array)).to eq(expected_user_array)
      end
    end

    context 'when value contains an invalid hash for a User object' do
      let(:invalid_user_array) { [{ first_name: 'John Doe' }, { work_email: 'jane@example.com' }] }

      it 'raises a TypeError' do
        expect {
          array_instance_with_user.cast(invalid_user_array)
        }.to raise_error(TypeError, "#{name} must be of type User")
      end
    end

    context 'when value is a valid array of User objects' do
      let(:user_1) { user_class.new(name: 'John Doe', email: 'john@example.com') }
      let(:user_2) { user_class.new(name: 'Jane Smith', email: 'jane@example.com') }
      let(:valid_user_object_array) { [user_1, user_2] }

      it 'returns the same array of User objects' do
        expect(array_instance_with_user.cast(valid_user_object_array)).to eq(valid_user_object_array)
      end
    end
  end
end
