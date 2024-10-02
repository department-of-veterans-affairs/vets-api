# frozen_string_literal: true

require 'rails_helper'
require 'vets/attributes'
require 'vets/model' # temporarily needed for Boolean

class FakeCategory
  include Vets::Attributes

  attribute :name, String, default: 'test'
end

class DummyParentModel
  include Vets::Attributes

  attribute :updated_at, DateTime, default: :current_time

  def current_time
    DateTime.new(2024, 9, 25, 10, 30, 0)
  end
end

class DummyModel < DummyParentModel
  include Vets::Attributes

  attribute :name, String, default: 'Unknown'
  attribute :age, Integer, array: false
  attribute :tags, String, array: true
  attribute :categories, FakeCategory, array: true
  attribute :created_at, DateTime, default: :current_time

  def current_time
    DateTime.new(2024, 9, 25, 10, 30, 0)
  end
end

RSpec.describe Vets::Attributes do
  let(:model) { DummyModel.new }

  describe '.attribute' do
    it 'defines the setters and getters' do
      model.age = 30
      model.tags = %w[ruby rails]
      model.name = 'Steven'
      expect(model.age).to eq(30)
      expect(model.tags).to eq(%w[ruby rails])
      expect(model.name).to eq('Steven')
    end

    it 'defines the defaults' do
      no_name = DummyModel.new
      expect(no_name.name).to eq('Unknown')
      expect(model.categories).to be_nil
    end

    it 'defines a default symbol as a method' do
      expected_time = DateTime.new(2024, 9, 25, 10, 30, 0)
      expect(model.created_at).to eq(expected_time)
    end
  end

  describe '.attributes' do
    it 'returns a hash of the attribute definitions' do
      expected_attributes = {
        name: { type: String, default: 'Unknown', array: false },
        age: { type: Integer, default: nil, array: false },
        tags: { type: String, default: nil, array: true },
        categories: { type: FakeCategory, default: nil, array: true },
        created_at: { type: DateTime, default: :current_time, array: false }
      }
      expect(DummyModel.attributes).to eq(expected_attributes)
    end
  end

  describe '.attribute_set' do
    it 'returns an array of the attribute names from itself' do
      expected_attribute_set = %i[name age tags categories created_at]
      expect(DummyModel.attribute_set).to include(*expected_attribute_set)
    end

    it 'includes an array of attributes from ancestors' do
      expect(DummyModel.attribute_set).to include(:updated_at)
    end
  end
end
