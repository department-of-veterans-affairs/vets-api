# frozen_string_literal: true

require 'rails_helper'
require 'vets/model/sortable'

RSpec.describe Vets::Model::Sortable do
  let(:dummy_class) { Class.new { include Vets::Model::Sortable } }

  # Test default_sort_by method
  describe '.default_sort_by' do
    it 'sets the default sort criteria correctly' do
      dummy_class.default_sort_by(name: :asc)

      expect(dummy_class.default_sort_criteria).to eq({ name: :asc })
    end

    it 'raises an error if more than one attribute is provided' do
      expect { dummy_class.default_sort_by(name: :asc, age: :desc) }
        .to raise_error(ArgumentError, 'Only one attribute and direction can be provided in default_sort_by')
    end

    it 'raises an error if the direction is invalid' do
      expect { dummy_class.default_sort_by(name: :up) }
        .to raise_error(ArgumentError, 'Direction must be either :asc or :desc')
    end
  end

  # Test comparison logic using <=> method
  describe '#<=>' do
    let(:dummy_class_with_data) do
      Class.new do
        include Vets::Model::Sortable

        attr_accessor :name, :age

        def initialize(name, age)
          @name = name
          @age = age
        end
      end
    end

    let(:user1) { dummy_class_with_data.new('Alice', 30) }
    let(:user2) { dummy_class_with_data.new('Bob', 25) }
    let(:user3) { dummy_class_with_data.new('Charlie', 35) }

    before do
      dummy_class_with_data.default_sort_by(name: :asc)
    end

    it 'compares objects based on the default sort criteria' do
      expect(user1 <=> user2).to eq(-1)  # 'Alice' < 'Bob'
      expect(user2 <=> user3).to eq(-1)  # 'Bob' < 'Charlie'
    end

    it 'compares objects in the specified direction' do
      dummy_class_with_data.default_sort_by(name: :desc)
      expect(user1 <=> user2).to eq(1) # 'Alice' > 'Bob' (because of :desc)
    end

    context 'when attribute is not comparable' do
      it 'raises an error' do
        name = OpenStruct.new(name: 'Alice')
        non_comparable_user = dummy_class_with_data.new(name, 21)
        expect { non_comparable_user <=> non_comparable_user.dup }
          .to raise_error(ArgumentError, "Attribute 'name' is not comparable.")
      end
    end
  end

  describe 'sorting' do
    let(:dummy_class_with_data) do
      Class.new do
        include Vets::Model::Sortable

        attr_accessor :name, :age

        def initialize(name, age)
          @name = name
          @age = age
        end
      end
    end

    let(:user1) { dummy_class_with_data.new('Alice', 30) }
    let(:user2) { dummy_class_with_data.new('Bob', 25) }
    let(:user3) { dummy_class_with_data.new('Charlie', 35) }
    let(:user4) { dummy_class_with_data.new('David', 20) }
    let(:user5) { dummy_class_with_data.new(nil, 20) }

    before do
      dummy_class_with_data.default_sort_by(name: :asc)
    end

    context 'when the default_sort_by is set' do
      it 'sorts by the default attribute (name) in ascending order' do
        users = [user1, user2, user3, user4]
        sorted_users = users.sort

        expect(sorted_users).to eq([user1, user2, user3, user4]) # 'Alice' < 'Bob' < 'Charlie' < 'David'
      end
    end

    context 'when there is no default_sort_by set' do
      let(:dummy_class_no_sort) do
        Class.new do
          include Vets::Model::Sortable

          attr_accessor :name, :age

          def initialize(name, age)
            @name = name
            @age = age
          end
        end
      end

      it 'does not apply any sorting' do
        no_sort_user1 = dummy_class_no_sort.new('Alice', 30)
        no_sort_user2 = dummy_class_no_sort.new('Bob', 25)
        no_sort_user3 = dummy_class_no_sort.new('Charlie', 35)
        no_sort_user4 = dummy_class_no_sort.new('David', 20)

        no_sort_users = [no_sort_user1, no_sort_user2, no_sort_user3, no_sort_user4]

        sorted = no_sort_users.sort
        expect(sorted).to eq([no_sort_user1, no_sort_user2, no_sort_user3, no_sort_user4])
      end
    end

    context 'when a value is nil' do
      it 'sorts the object with nil to the end' do
        users = [user1, user2, user3, user4, user5]
        sorted_users = users.sort

        expect(sorted_users.last).to eq(user5)
      end
    end
  end
end
