# frozen_string_literal: true

require 'rails_helper'

class Pet < Common::Base
  attribute :species, String
  attribute :age, Integer
end

describe Mobile::ListFilter, aggregate_failures: true do
  let(:dog) do
    Pet.new(species: 'dog', age: 5)
  end
  let(:puppy) do
    Pet.new(species: 'dog', age: 1)
  end
  let(:cat) do
    Pet.new(species: 'cat', age: 12)
  end
  let(:list) do
    Common::Collection.new(data: [dog, puppy, cat])
  end

  def paramiterize(params)
    ActionController::Parameters.new(params)
  end

  describe '.matches' do
    it 'finds matches with the eq operator' do
      filters = { species: { eq: 'dog' } }
      params = paramiterize(filters)

      results = Mobile::ListFilter.matches(list, params)
      expect(results.data).to eq([dog, puppy])
    end

    it 'excludes non-matches with the notEq operator' do
      filters = { species: { notEq: 'dog' } }
      params = paramiterize(filters)

      results = Mobile::ListFilter.matches(list, params)
      expect(results.data).to eq([cat])
    end

    it 'handles multiple filters' do
      filters = { species: { eq: 'dog' }, age: { notEq: 5 } }
      params = paramiterize(filters)

      results = Mobile::ListFilter.matches(list, params)
      expect(results.data).to eq([puppy])
    end

    it 'returns a collection with an empty array of data when no matches are found' do
      filters = { species: { eq: 'turtle' } }
      params = paramiterize(filters)

      results = Mobile::ListFilter.matches(list, params)
      expect(results.class).to eq(Common::Collection)
      expect(results.data).to eq([])
    end

    it 'returns the collection when empty filters are provided' do
      params = paramiterize({})

      results = Mobile::ListFilter.matches(list, params)
      expect(results.data).to eq(list.data)
      expect(results.metadata).to eq({ filter: params })
    end

    it 'retains any errors or metadata contained in the original collection' do
      errors = { error: 'the original error' }
      metadata = { meta: 'data' }
      list.errors = errors
      list.metadata = metadata
      filters = { species: { eq: 'dog' } }
      params = paramiterize(filters)
      expected_metadata = metadata.merge(filter: params)

      results = Mobile::ListFilter.matches(list, params)
      expect(results.errors).to eq(errors)
      expect(results.metadata).to eq(expected_metadata)
    end
  end
end
