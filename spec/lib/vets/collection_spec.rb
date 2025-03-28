# frozen_string_literal: true

require 'rails_helper'
require 'vets/collection'
require 'vets/model'

RSpec.describe Vets::Collection do
  let(:dummy_class) do
    Class.new do
      include Vets::Model

      attribute :name, String
      attribute :age, Integer

      set_pagination per_page: 21, max_per_page: 41

      def <=>(other)
        name <=> other.name
      end

      def self.filterable_attributes
        {
          'name' => %w[match eq],
          'age' => %w[eq gteq lteq]
        }.with_indifferent_access
      end
    end
  end

  describe '#initialize' do
    it 'initializes with sorted records' do
      record1 = dummy_class.new(name: 'Bob', age: 25)
      record2 = dummy_class.new(name: 'Alice', age: 30)

      collection = described_class.new([record1, record2])
      expect(collection.records).to eq([record2, record1])
    end

    it 'raises an error if records are not all the same class' do
      record1 = dummy_class.new(name: 'Alice', age: 30)
      record2 = Object.new

      expect { described_class.new([record1, record2]) }
        .to raise_error(ArgumentError, "All records must be instances of #{dummy_class}")
    end

    it 'returns an empty Collections if records are nil' do
      collection = described_class.new(nil)
      expect(collection.records).to eq([])
      expect(collection.instance_variable_get(:@model_class)).to be_nil
    end

    it 'returns an empty Collections if records are empty' do
      collection = described_class.new([])
      expect(collection.records).to eq([])
      expect(collection.instance_variable_get(:@model_class)).to be_nil
    end
  end

  describe '.from_hashes' do
    it 'creates a collection from an WillPaginate::Collection' do
      hashes = [{ name: 'Alice', age: 30 }, { name: 'Bob', age: 25 }]
      collection = described_class.from_hashes(dummy_class, hashes)
      expect(collection.records.map(&:name)).to eq(%w[Alice Bob])
    end

    it 'raises an error if not a WillPaginate::Collection' do
      hashes = [{ name: 'Alice', age: 30 }, 'invalid']

      expect { described_class.from_hashes(dummy_class, hashes) }
        .to raise_error(ArgumentError, 'Expected an array of hashes')
    end
  end

  describe '.will_paginate' do
    it 'creates a collection from an array of hashes' do
      record1 = dummy_class.new(name: 'Bob', age: 25)
      record2 = dummy_class.new(name: 'Alice', age: 30)
      records = [record1, record2]

      will_collection = WillPaginate::Collection.create(1, 2, records.size) do |pager|
        pager.replace(records[0, 2])
      end
      collection = described_class.from_will_paginate(will_collection)
      expect(collection.records.map(&:name)).to eq(%w[Alice Bob])
    end

    it 'raises an error if any element is not a hash' do
      hashes = [{ name: 'Alice', age: 30 }, 'invalid']

      expect { described_class.from_will_paginate(hashes) }
        .to raise_error(ArgumentError, 'Expected records to be instance of WillPaginate')
    end
  end

  describe '#where' do
    let(:records) do
      [
        dummy_class.new(name: 'Alice', age: 30),
        dummy_class.new(name: 'Bob', age: 40),
        dummy_class.new(name: 'Charlie', age: 50)
      ]
    end

    let(:collection) { described_class.new(records) }

    it 'returns a filtered collection based on conditions' do
      results = collection.where(age: { eq: 40 })
      expect(results.records.map(&:name)).to contain_exactly('Bob')
      expect(results.metadata[:filter]).to eq(age: { eq: 40 })
    end

    it 'returns an empty collection if no records match' do
      results = collection.where(age: { eq: 60 })
      expect(results.records).to be_empty
      expect(results.metadata[:filter]).to eq(age: { eq: 60 })
    end
  end

  describe '#find_by' do
    let(:records) do
      [
        dummy_class.new(name: 'Alice', age: 30),
        dummy_class.new(name: 'Bob', age: 40),
        dummy_class.new(name: 'Charlie', age: 50)
      ]
    end

    let(:collection) { described_class.new(records) }

    it 'returns the first record that matches the conditions' do
      result = collection.find_by(age: { gteq: 40 })
      expect(result.name).to eq('Bob')
    end

    it 'returns nil if no record matches the conditions' do
      result = collection.find_by(age: { eq: 60 })
      expect(result).to be_nil
    end
  end

  describe '#order' do
    let(:record1) { dummy_class.new(name: 'Alice', age: 30) }
    let(:record2) { dummy_class.new(name: 'Bob', age: 25) }
    let(:record3) { dummy_class.new(name: 'Charlie', age: 35) }
    let(:record4) { dummy_class.new(name: 'David', age: 25) }
    let(:record5) { dummy_class.new(name: 'Emma', age: nil) }

    let(:collection) { described_class.new([record4, record1, record2, record3]) }

    it 'returns records sorted by the specified attribute in ascending order' do
      sorted = collection.order(name: :asc)
      expect(sorted).to eq([record1, record2, record3, record4])
    end

    it 'returns records sorted by the specified attribute in descending order' do
      sorted = collection.order(name: :desc)
      expect(sorted).to eq([record4, record3, record2, record1])
    end

    it 'handles sorting by multiple attributes' do
      sorted = collection.order(age: :asc, name: :desc)
      expect(sorted).to eq([record4, record2, record1, record3])
    end

    it 'raises an error if an attribute is not a symbol' do
      expect { collection.order('name' => :asc) }
        .to raise_error(ArgumentError, 'Attribute name must be a symbol')
    end

    it 'raises an error if an attribute does not exist' do
      expect { collection.order(nonexistent: :asc) }
        .to raise_error(ArgumentError, 'Attribute nonexistent does not exist on the model')
    end

    it 'raises an error if the direction is invalid' do
      expect { collection.order(name: :invalid) }
        .to raise_error(ArgumentError, 'Direction invalid must be :asc or :desc')
    end

    it 'raises an error if no clauses are provided' do
      expect { collection.order }
        .to raise_error(ArgumentError, 'Order must have at least one sort clause')
    end

    it 'forces null values to end of the array' do
      collection = described_class.new([record4, record1, record5, record2, record3])
      sorted = collection.order(age: :asc)
      expect(sorted.last).to eq(record5)
    end
  end

  describe '#paginate' do
    context 'when page and per_page are provided' do
      it 'returns a paginated collection with correct metadata' do
        record1 = dummy_class.new(name: 'Bob', age: 25)
        record2 = dummy_class.new(name: 'Alice', age: 30)
        record3 = dummy_class.new(name: 'Steven', age: 30)
        records = [record1, record2, record3]

        collection = described_class.new(records)

        paginated = collection.paginate(page: 2, per_page: 2)
        metadata = paginated.metadata[:pagination]

        expect(paginated).to be_a(Vets::Collection)
        expect(metadata[:current_page]).to eq(2)
        expect(metadata[:per_page]).to eq(2)
        expect(metadata[:total_entries]).to eq(3)
        expect(metadata[:total_pages]).to eq(2)
        expect(paginated.records).to eq([record3])
      end
    end

    context 'when page is not provided or invalid' do
      it 'defaults to the first page' do
        record1 = dummy_class.new(name: 'Bob', age: 25)
        record2 = dummy_class.new(name: 'Alice', age: 30)
        records = [record2, record1]

        collection = described_class.new(records)

        paginated = collection.paginate(page: nil, per_page: 10)
        metadata = paginated.metadata[:pagination]
        expect(metadata[:current_page]).to eq(1)
        expect(paginated.records).to eq(records[0..1])

        paginated = collection.paginate(page: -1, per_page: 10)
        expect(metadata[:current_page]).to eq(1)
        expect(paginated.records).to eq(records[0..1])
      end
    end

    context 'when per_page is invalid' do
      context 'when the model class has a per_page default' do
        it 'defaults to the model per_page value' do
          record1 = dummy_class.new(name: 'Bob', age: 25)
          record2 = dummy_class.new(name: 'Alice', age: 30)

          collection = described_class.new([record1, record2])

          paginated = collection.paginate(page: 1, per_page: nil)
          metadata = paginated.metadata[:pagination]
          expect(metadata[:per_page]).to eq(21)
        end
      end

      context 'when the model class does not have a per_page default' do
        let(:dummy_class) do
          Class.new do
            include Vets::Model

            attribute :name, String
            attribute :age, Integer
          end
        end

        it 'defaults to the collection default per page' do
          record1 = dummy_class.new(name: 'Bob', age: 25)
          record2 = dummy_class.new(name: 'Alice', age: 30)

          collection = described_class.new([record1, record2])
          paginated = collection.paginate(page: 1, per_page: nil)
          metadata = paginated.metadata[:pagination]

          expect(metadata[:per_page]).to eq(10) # respects model max_per_page
        end
      end
    end

    context 'when per_page is higher than max' do
      context 'when the model class has a max_per_page default' do
        it 'defaults to the model max_per_page value' do
          record1 = dummy_class.new(name: 'Bob', age: 25)
          record2 = dummy_class.new(name: 'Alice', age: 30)

          collection = described_class.new([record1, record2])

          paginated = collection.paginate(page: 1, per_page: 1000)
          metadata = paginated.metadata[:pagination]
          expect(metadata[:per_page]).to eq(41)
        end
      end

      context 'when the model class does not have a per_page default' do
        let(:dummy_class) do
          Class.new do
            include Vets::Model

            attribute :name, String
            attribute :age, Integer
          end
        end

        it 'defaults to the collection default per page' do
          record1 = dummy_class.new(name: 'Bob', age: 25)
          record2 = dummy_class.new(name: 'Alice', age: 30)

          collection = Vets::Collection.new([record1, record2])
          paginated = collection.paginate(page: 1, per_page: 1000)
          metadata = paginated.metadata[:pagination]

          expect(metadata[:per_page]).to eq(100)
        end
      end
    end

    context 'when no records exist' do
      let(:records) { [] }

      it 'returns an empty collection with correct metadata' do
        collection = Vets::Collection.new(records)
        paginated = collection.paginate(page: 1, per_page: 10)
        metadata = paginated.metadata[:pagination]

        expect(metadata[:current_page]).to eq(1)
        expect(metadata[:per_page]).to eq(10)
        expect(metadata[:total_entries]).to eq(0)
        expect(metadata[:total_pages]).to eq(1)
        expect(paginated.records).to be_empty
      end
    end
  end
end
