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

    describe 'data validation and error handling' do
      before do
        Settings.sentry.dsn = 'asdf'
      end

      after do
        Settings.sentry.dsn = nil
      end

      it 'logs an error and returns original collection when collection is not a Common::Collection' do
        params = paramiterize({})

        expect(Raven).to receive(:capture_exception).once.with(Mobile::ListFilter::FilterError, { level: 'error' })
        expect(Raven).to receive(:extra_context).with({ filters: params.to_unsafe_hash })
        result = Mobile::ListFilter.matches([], params)
        expect(result).to eq([])
      end

      it 'logs an error and returns original collection when filters are not an ActionController::Params object' do
        expect(Raven).to receive(:capture_exception).once.with(Mobile::ListFilter::FilterError, { level: 'error' })
        expect(Raven).to receive(:extra_context).with({ collection_models: ['Pet'] })
        result = Mobile::ListFilter.matches(list, {})
        expect(result.data).to eq(list.data)
        expect(result.errors).to eq({ filter_error: 'filters must be an ActionController::Parameters' })
      end

      it 'logs an error and returns original collection when collection contains mixed models' do
        params = paramiterize({})
        mixed_list = Common::Collection.new(data: [dog, 'string'])

        expect(Raven).to receive(:capture_exception).once.with(Mobile::ListFilter::FilterError, { level: 'error' })
        expect(Raven).to receive(:extra_context).with(
          { filters: params.to_unsafe_hash, collection_models: %w[Pet String] }
        )
        result = Mobile::ListFilter.matches(mixed_list, params)
        expect(result.data).to eq(mixed_list.data)
        expect(result.errors).to eq({ filter_error: 'collection contains multiple models' })
      end

      it 'logs an error and returns original collection when the model does contain the requested filter attribute' do
        params = paramiterize({ genus: { eq: 'dog' } })

        expect(Raven).to receive(:capture_exception).once.with(Mobile::ListFilter::FilterError, { level: 'error' })
        expect(Raven).to receive(:extra_context).with({ filters: params.to_unsafe_hash, collection_models: ['Pet'] })
        result = Mobile::ListFilter.matches(list, params)
        expect(result.data).to eq(list.data)
        expect(result.errors).to eq({ filter_error: 'invalid attribute' })
      end

      it 'logs an error and returns original collection when the filter is not a hash' do
        params = paramiterize({ genus: 'dog' })

        expect(Raven).to receive(:capture_exception).once.with(Mobile::ListFilter::FilterError, { level: 'error' })
        expect(Raven).to receive(:extra_context).with({ filters: params.to_unsafe_hash, collection_models: ['Pet'] })
        result = Mobile::ListFilter.matches(list, params)
        expect(result.data).to eq(list.data)
        expect(result.errors).to eq({ filter_error: 'invalid filter structure' })
      end

      it 'logs an error and returns original collection when the filter contains multiple operations' do
        params = paramiterize({ genus: { eq: 'dog', notEq: 'cat' } })

        expect(Raven).to receive(:capture_exception).once.with(Mobile::ListFilter::FilterError, { level: 'error' })
        expect(Raven).to receive(:extra_context).with({ filters: params.to_unsafe_hash, collection_models: ['Pet'] })
        result = Mobile::ListFilter.matches(list, params)
        expect(result.data).to eq(list.data)
        expect(result.errors).to eq({ filter_error: 'invalid filter structure' })
      end

      it 'logs an error and returns original collection when the requested filter operation is not supported' do
        params = paramiterize({ species: { fuzzyEq: 'dog' } })

        expect(Raven).to receive(:capture_exception).once.with(Mobile::ListFilter::FilterError, { level: 'error' })
        expect(Raven).to receive(:extra_context).with({ filters: params.to_unsafe_hash, collection_models: ['Pet'] })
        result = Mobile::ListFilter.matches(list, params)
        expect(result.data).to eq(list.data)
        expect(result.errors).to eq({ filter_error: 'invalid operation' })
      end

      it 'logs an error and returns collection when an unexpected error occurs' do
        params = paramiterize({})
        allow_any_instance_of(Mobile::ListFilter).to receive(:matches).and_raise(StandardError)

        expect(Raven).to receive(:capture_exception).once.with(StandardError, { level: 'error' })
        expect(Raven).to receive(:extra_context).with({ filters: params.to_unsafe_hash, collection_models: ['Pet'] })
        result = Mobile::ListFilter.matches(list, params)
        expect(result.data).to eq(list.data)
        expect(result.errors).to eq({ filter_error: 'unknown filter error' })
      end
    end
  end
end
