# frozen_string_literal: true

require 'rails_helper'
require 'vets/collection/finder'
require 'vets/model'

RSpec.describe Vets::Collections::Finder do
  let(:dummy_class) do
    Class.new do
      include Vets::Model

      attribute :name, String
      attribute :age, Integer

      set_pagination per_page: 21, max_per_page: 41

      # Simulating filterable attributes for this dummy model
      def self.filterable_attributes
        { name: %w[match eq], age: %w[eq lteq gteq] }
      end
    end
  end

  let(:data) do
    [
      dummy_class.new(name: 'John Doe', age: 30),
      dummy_class.new(name: 'Jane Smith', age: 40),
      dummy_class.new(name: 'Jim Brown', age: 50)
    ]
  end

  let(:finder) { described_class.new(data: data) }

  describe '#all' do
    context 'when valid conditions are passed' do
      it 'returns filtered data based on conditions' do
        conditions = { name: { eq: 'John Doe' } }
        result = finder.all(conditions)

        expect(result.size).to eq(1)
        expect(result.first.name).to eq('John Doe')
      end

      it 'returns filtered data using multiple conditions' do
        conditions = { age: { lteq: 40 } }
        result = finder.all(conditions)

        expect(result.size).to eq(2)
        expect(result.map(&:name)).to include('John Doe', 'Jane Smith')
      end
    end

    context 'when invalid conditions are passed' do
      it 'raises FilterNotAllowed for an invalid attribute' do
        conditions = { invalid_attr: { eq: 'some value' } }
        expect { finder.all(conditions) }.to raise_error(Common::Exceptions::FilterNotAllowed)
      end

      it 'raises FilterNotAllowed for an invalid operation' do
        conditions = { name: { not_eq: 'John Doe' } }
        expect { finder.all(conditions) }.to raise_error(Common::Exceptions::FilterNotAllowed)
      end
    end
  end

  describe '#first' do
    context 'when valid conditions are passed' do
      it 'returns the first filtered item' do
        conditions = { name: { eq: 'Jane Smith' } }
        result = finder.first(conditions)

        expect(result.name).to eq('Jane Smith')
      end
    end

    context 'when no match is found' do
      it 'returns nil' do
        conditions = { name: { eq: 'Nonexistent Name' } }
        result = finder.first(conditions)

        expect(result).to be_nil
      end
    end
  end

  describe '#compare' do
    context 'when valid conditions are passed' do
      it 'compares correctly with equality operator' do
        conditions = { name: { eq: 'John Doe' } }
        object = dummy_class.new(name: 'John Doe', age: 30)
        result = finder.send(:compare, object, conditions)

        expect(result).to be_truthy
      end

      it 'compares correctly with match operator' do
        conditions = { name: { match: 'John' } }
        object = dummy_class.new(name: 'John Doe', age: 30)
        result = finder.send(:compare, object, conditions)

        expect(result).to be_truthy
      end

      it 'returns false for mismatched conditions' do
        conditions = { name: { eq: 'Jim Brown' } }
        object = dummy_class.new(name: 'John Doe', age: 30)
        result = finder.send(:compare, object, conditions)

        expect(result).to be_falsey
      end
    end

    context 'when invalid syntax is passed' do
      it 'raises InvalidFiltersSyntax for invalid filters' do
        conditions = { name: { invalid_op: 'John Doe' } }
        object = dummy_class.new(name: 'John Doe', age: 30)

        expect { finder.send(:compare, object, conditions) }.to raise_error(Common::Exceptions::InvalidFiltersSyntax)
      end
    end
  end

  describe 'validations' do
    it 'raises FilterNotAllowed for unsupported operations' do
      conditions = { age: { not_eq: 30 } }
      expect { finder.send(:validate_conditions, conditions) }.to raise_error(Common::Exceptions::FilterNotAllowed)
    end

    it 'raises FilterNotAllowed for unsupported attributes' do
      conditions = { unknown_attr: { eq: 'value' } }
      expect { finder.send(:validate_conditions, conditions) }.to raise_error(Common::Exceptions::FilterNotAllowed)
    end
  end
end
