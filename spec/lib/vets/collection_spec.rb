# frozen_string_literal: true

require 'rails_helper'
require 'vets/collection'

RSpec.describe Vets::Collection do

end
# frozen_string_literal: true

require 'rails_helper'
require 'vets/collection'

RSpec.describe Vets::Collection do
  let(:dummy_class) do
    Class.new do
      attr_accessor :name, :age

      def initialize(name:, age:)
        @name = name
        @age = age
      end

      def <=>(other)
        name <=> other.name
      end
    end
  end

  describe '#initialize' do
    it 'initializes with sorted records' do
      record1 = dummy_class.new(name: 'Bob', age: 25)
      record2 = dummy_class.new(name: 'Alice', age: 30)

      collection = Vets::Collection.new([record1, record2])
      expect(collection.instance_variable_get(:@records)).to eq([record2, record1])
    end

    it 'raises an error if records are not all the same class' do
      record1 = dummy_class.new(name: 'Alice', age: 30)
      record2 = Object.new

      expect { Vets::Collection.new([record1, record2]) }
        .to raise_error(ArgumentError, "All records must be instances of #{dummy_class}")
    end
  end

  describe '.from_hashes' do
    it 'creates a collection from an array of hashes' do
      hashes = [{ name: 'Alice', age: 30 }, { name: 'Bob', age: 25 }]
      collection = Vets::Collection.from_hashes(dummy_class, hashes)

      expect(collection.instance_variable_get(:@records).map(&:name)).to eq(['Alice', 'Bob'])
    end

    it 'raises an error if any element is not a hash' do
      hashes = [{ name: 'Alice', age: 30 }, 'invalid']

      expect { Vets::Collection.from_hashes(dummy_class, hashes) }
        .to raise_error(ArgumentError, 'Expected an array of hashes')
    end
  end

  describe '#order' do
    let(:record1) { dummy_class.new(name: 'Alice', age: 30) }
    let(:record2) { dummy_class.new(name: 'Bob', age: 25) }
    let(:record3) { dummy_class.new(name: 'Charlie', age: 35) }
    let(:record4) { dummy_class.new(name: 'David', age: 25) }

    let(:collection) { Vets::Collection.new([record4, record1, record2, record3]) }

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
  end
end
