require 'rails_helper'
require 'vets/type/primitive'

RSpec.describe Vets::Type::Primitive do
  let(:name) { 'test_primitive' }

  shared_examples 'primitive type casting' do |klass, valid_input, expected_output, invalid_input|
    let(:primitive_instance) { described_class.new(name, klass) }

    context "when klass is #{klass}" do
      it 'casts valid input correctly' do
        expect(primitive_instance.cast(valid_input)).to eq(expected_output)
      end

      it 'raises TypeError for invalid input' do
        expect {
          primitive_instance.cast(invalid_input)
        }.to raise_error(TypeError, "#{name} could not be coerced to #{klass}")
      end
    end
  end

  describe '#cast' do
    context 'when value is nil' do
      let(:primitive_instance) { described_class.new(name, String) }

      it 'returns nil' do
        expect(primitive_instance.cast(nil)).to be_nil
      end
    end

    include_examples 'primitive type casting', Integer, '42', 42, 'invalid'
    include_examples 'primitive type casting', Float, '3.14', 3.14, 'invalid'
    include_examples 'primitive type casting', Date, '2024-12-19', Date.new(2024, 12, 19), 'invalid'
    include_examples 'primitive type casting', DateTime, '2024-12-19T12:34:56+00:00', DateTime.new(2024, 12, 19, 12, 34, 56), 'invalid'
    include_examples 'primitive type casting', String, 42, '42', nil

    context 'when klass is unsupported' do
      let(:primitive_instance) { described_class.new(name, Hash) }

      it 'raises TypeError for unsupported types' do
        expect {
          primitive_instance.cast('value')
        }.to raise_error(TypeError, "#{name} could not be coerced to Hash")
      end
    end
  end
end
