# frozen_string_literal: true

require 'rails_helper'
require 'vets/model'
require 'vets/collections/finder'

RSpec.describe Vets::Collections::Finder do
  let(:dummy_class) do
    Class.new do
      include Vets::Model

      attribute :name, String
      attribute :age, Integer

      set_pagination per_page: 21, max_per_page: 41

      def self.filterable_attributes
        { name: %w[match eq], age: %w[eq lteq gteq] }.with_indifferent_access
      end
    end
  end

  let(:dummy_data) do
    [
      dummy_class.new(name: 'John Doe', age: 30),
      dummy_class.new(name: 'Jane Smith', age: 40),
      dummy_class.new(name: 'Jim Brown', age: 50),
      dummy_class.new(name: 'Alice White', age: 25)
    ]
  end

  let(:finder) { described_class.new(data: dummy_data) }

  describe '#all' do
    context 'with valid filters' do
      it 'returns filtered results based on conditions' do
        conditions = { age: { lteq: 40 }, name: { match: 'John' } }
        result = finder.all(conditions)

        expect(result.size).to eq(1)
        expect(result.first.name).to eq('John Doe')
      end

      it 'returns an empty array when no results match' do
        conditions = { age: { gteq: 60 } }
        result = finder.all(conditions)

        expect(result).to eq([])
      end
    end

    context 'with invalid filters' do
      it 'raises a FilterNotAllowed error for invalid attributes' do
        conditions = { invalid_attribute: { eq: 'value' } }

        expect do
          finder.all(conditions)
        end.to raise_error(Common::Exceptions::FilterNotAllowed, 'Filter not allowed')
      end

      it 'raises a FilterNotAllowed error for invalid operations' do
        conditions = { age: { invalid_op: 30 } }

        expect do
          finder.all(conditions)
        end.to raise_error(Common::Exceptions::FilterNotAllowed, 'Filter not allowed')
      end

      it 'raises an InvalidFiltersSyntax error for malformed conditions' do
        conditions = { age: { gteq: 'invalid_value' } }

        expect do
          finder.all(conditions)
        end.to raise_error(Common::Exceptions::InvalidFiltersSyntax)
      end

      it 'raises an InvalidFiltersSyntax error for nil conditions' do
        conditions = nil
        expect do
          finder.all(conditions)
        end.to raise_error(Common::Exceptions::InvalidFiltersSyntax)
      end
    end
  end

  describe '#first' do
    it 'returns the first matching result based on conditions' do
      conditions = { age: { lteq: 40 } }
      result = finder.first(conditions)

      expect(result.name).to eq('John Doe')
    end

    it 'returns nil when no results match' do
      conditions = { age: { gteq: 60 } }
      result = finder.first(conditions)

      expect(result).to be_nil
    end
  end
end
