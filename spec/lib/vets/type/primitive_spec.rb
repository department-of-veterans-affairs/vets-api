# frozen_string_literal: true

require 'rails_helper'
require 'vets/type/primitive'

RSpec.describe Vets::Type::Primitive do
  let(:name) { 'test_primitive' }

  describe '#cast' do
    context 'when value is nil' do
      let(:primitive_instance) { described_class.new(name, String) }

      it 'returns nil' do
        expect(primitive_instance.cast(nil)).to be_nil
      end
    end

    context 'when klass is Integer' do
      let(:primitive_instance) { described_class.new(name, Integer) }

      it 'casts valid input correctly' do
        expect(primitive_instance.cast('42')).to eq(42)
        expect(primitive_instance.cast('valid')).to eq(0)
      end

      it 'cast invalid input to nil' do
        expect(primitive_instance.cast(nil)).to be_nil
      end
    end

    context 'when klass is Float' do
      let(:primitive_instance) { described_class.new(name, Float) }

      it 'casts valid input correctly' do
        expect(primitive_instance.cast('3.14')).to eq(3.14)
        expect(primitive_instance.cast('valid')).to eq(0.0)
      end

      it 'cast valid to nil' do
        expect(primitive_instance.cast(nil)).to be_nil
      end

      it 'raises TypeError for invalid input' do
        expect do
          primitive_instance.cast(Object.new)
        end.to raise_error(TypeError, "#{name} could not be casted to Float")
      end
    end

    context 'when klass is Date' do
      let(:primitive_instance) { described_class.new(name, Date) }

      it 'casts valid input correctly' do
        expect(primitive_instance.cast('2024-12-19')).to eq(Date.new(2024, 12, 19))
      end

      it 'cast invalid input to nil' do
        expect(primitive_instance.cast(nil)).to be_nil
      end
    end

    context 'when klass is DateTime' do
      let(:primitive_instance) { described_class.new(name, DateTime) }

      it 'casts valid input correctly' do
        expect(primitive_instance.cast('2024-12-19T12:34:56+00:00')).to eq(DateTime.new(2024, 12, 19, 12, 34, 56))
      end

      it 'cast invalid input to nil' do
        expect(primitive_instance.cast(nil)).to be_nil
      end
    end

    context 'when klass is Time' do
      let(:primitive_instance) { described_class.new(name, Time) }

      it 'casts valid input correctly for ISO8601 format' do
        date_time_string = '2024-12-19T12:34:56+00:00'
        expect(primitive_instance.cast(date_time_string)).to eq(Time.iso8601(date_time_string))
      end

      it 'casts valid input correctly for HTTP date format' do
        date_time_string = 'Wed, 19 Dec 2024 12:34:56 GMT'
        expect(primitive_instance.cast(date_time_string)).to eq(Time.httpdate(date_time_string))
      end

      it 'casts valid input correctly for custom date-time format' do
        expect(primitive_instance.cast('2024-12-19 12:34:56')).to eq(Time.zone.parse('2024-12-19 12:34:56'))
      end

      it 'casts valid input correctly for custom time format' do
        expect(primitive_instance.cast('12:34:56')).to eq(Time.zone.parse('12:34:56'))
      end

      it 'casts invalid input to nil' do
        expect(primitive_instance.cast(nil)).to be_nil
      end
    end

    context 'when klass is String' do
      let(:primitive_instance) { described_class.new(name, String) }

      it 'casts valid input correctly' do
        expect(primitive_instance.cast(42)).to eq('42')
      end

      it 'cast nil to nil' do
        expect(primitive_instance.cast(nil)).to be_nil
      end
    end
  end
end
