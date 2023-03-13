# frozen_string_literal: true

require 'rails_helper'
require 'common/models/resource'

class PetBase < Common::Base
  attribute :species, String
  attribute :age, Integer
  attribute :fully_vaccinated, Boolean
end

class PetResource < Common::Resource
  attribute :species, Types::String
  attribute :age, Types::Integer
  attribute :fully_vaccinated, Types::Bool.optional
end

describe Mobile::ListFilter, aggregate_failures: true do
  let(:dog) do
    PetResource.new(species: 'dog', age: 5, fully_vaccinated: true)
  end
  let(:puppy) do
    PetResource.new(species: 'dog', age: 1, fully_vaccinated: false)
  end
  let(:cat) do
    PetResource.new(species: 'cat', age: 12, fully_vaccinated: nil)
  end
  let(:list) do
    [dog, puppy, cat]
  end

  def paramiterize(params)
    # ensuring param values are strings because they will always be strings when coming from controllers
    params.each_pair do |key, operation_value_pair|
      operation_value_pair.each { |operation, value| params[key][operation] = value.to_s }
    end
    ActionController::Parameters.new(params)
  end

  describe '.matches' do
    it 'finds matches with the eq operator' do
      filters = { species: { eq: 'dog' } }
      params = paramiterize(filters)

      results, error = Mobile::ListFilter.matches(list, params)
      expect(results).to eq([dog, puppy])
      expect(error).to be_nil
    end

    it 'excludes non-matches with the not_eq operator' do
      filters = { species: { not_eq: 'dog' } }
      params = paramiterize(filters)

      results, error = Mobile::ListFilter.matches(list, params)
      expect(results).to eq([cat])
      expect(error).to be_nil
    end

    it 'handles multiple filters' do
      filters = { species: { eq: 'dog' }, age: { not_eq: 5 } }
      params = paramiterize(filters)

      results, error = Mobile::ListFilter.matches(list, params)
      expect(results).to eq([puppy])
      expect(error).to be_nil
    end

    it 'matches non-string attributes' do
      filters = { age: { eq: 1 }, fully_vaccinated: { eq: false } }
      params = paramiterize(filters)

      results, error = Mobile::ListFilter.matches(list, params)
      expect(results).to eq([puppy])
      expect(error).to be_nil
    end

    it 'returns a list with an empty array of data when no matches are found' do
      filters = { species: { eq: 'turtle' } }
      params = paramiterize(filters)

      results, error = Mobile::ListFilter.matches(list, params)
      expect(results).to eq([])
      expect(error).to be_nil
    end

    it 'returns the list when filters are nil' do
      result, error = Mobile::ListFilter.matches(list, nil)
      expect(result).to eq(list)
      expect(error).to be_nil
    end

    it 'returns the list when empty filters are provided' do
      params = paramiterize({})

      results, error = Mobile::ListFilter.matches(list, params)
      expect(results).to eq(list)
      expect(error).to be_nil
    end

    it 'filters an array of Common::Resource objects' do
      filters = { species: { eq: 'cat' } }
      params = paramiterize(filters)

      results, error = Mobile::ListFilter.matches(list, params)
      expect(results).to eq([cat])
      expect(error).to be_nil
    end

    it 'filters an array of Common::Base objects' do
      filters = { species: { eq: 'dog' } }
      params = paramiterize(filters)
      base_pup = PetBase.new(species: 'dog', age: 1, fully_vaccinated: false)
      base_dog = PetBase.new(species: 'dog', age: 5, fully_vaccinated: true)
      base_cat = PetBase.new(species: 'cat', age: 12, fully_vaccinated: nil)
      base_list = [base_pup, base_dog, base_cat]

      results, error = Mobile::ListFilter.matches(base_list, params)
      expect(results).to eq([base_pup, base_dog])
      expect(error).to be_nil
    end

    describe 'data validation and error handling' do
      before { allow(Settings.sentry).to receive(:dsn).and_return('asdf') }

      it 'logs an error and returns original list when list is not an array' do
        params = paramiterize({})

        expect(Raven).to receive(:capture_exception).once.with(Mobile::ListFilter::FilterError, { level: 'error' })
        expect(Raven).to receive(:extra_context).with({ filters: params.to_unsafe_hash })
        result, error = Mobile::ListFilter.matches({}, params)
        expect(result).to eq({})
        expect(error.class).to eq(Mobile::ListFilter::FilterError)
        expect(error.message).to eq('list must be an array')
      end

      it 'logs an error and returns original list when filters are not an ActionController::Params object' do
        expect(Raven).to receive(:capture_exception).once.with(Mobile::ListFilter::FilterError, { level: 'error' })
        expect(Raven).to receive(:extra_context).with({ list_models: ['PetResource'] })
        result, error = Mobile::ListFilter.matches(list, {})
        expect(result).to eq(list)
        expect(error.class).to eq(Mobile::ListFilter::FilterError)
        expect(error.message).to eq('filters must be an ActionController::Parameters')
      end

      it 'logs an error and returns original list when list contains mixed models' do
        params = paramiterize({})
        mixed_list = [dog, 'string']

        expect(Raven).to receive(:capture_exception).once.with(Mobile::ListFilter::FilterError, { level: 'error' })
        expect(Raven).to receive(:extra_context).with(
          { filters: params.to_unsafe_hash, list_models: %w[PetResource String] }
        )
        result, error = Mobile::ListFilter.matches(mixed_list, params)
        expect(result).to eq(mixed_list)
        expect(error.class).to eq(Mobile::ListFilter::FilterError)
        expect(error.message).to eq('list contains multiple data types')
      end

      it 'logs an error and returns original list when the list contains data types that are not Common::Base' do
        params = paramiterize({ genus: { eq: 'dog' } })
        invalid_list = [{ species: 'dog', age: 3, fully_vaccinated: true }]

        expect(Raven).to receive(:capture_exception).once.with(Mobile::ListFilter::FilterError, { level: 'error' })
        expect(Raven).to receive(:extra_context).with({ filters: params.to_unsafe_hash, list_models: ['Hash'] })
        result, error = Mobile::ListFilter.matches(invalid_list, params)
        expect(result).to eq(invalid_list)
        expect(error.class).to eq(Mobile::ListFilter::FilterError)
        expect(error.message).to eq('list items must be Common::Resource or Common::Base models')
      end

      it 'logs an error and returns original list when the model does contain the requested filter attribute' do
        params = paramiterize({ genus: { eq: 'dog' } })

        expect(Raven).to receive(:capture_exception).once.with(Mobile::ListFilter::FilterError, { level: 'error' })
        expect(Raven).to receive(:extra_context).with({ filters: params.to_unsafe_hash, list_models: ['PetResource'] })
        result, error = Mobile::ListFilter.matches(list, params)
        expect(result).to eq(list)
        expect(error.class).to eq(Mobile::ListFilter::FilterError)
        expect(error.message).to eq('invalid attribute')
      end

      it 'logs an error and returns original list when the filter is not a hash' do
        params = ActionController::Parameters.new({ genus: 'dog' })

        expect(Raven).to receive(:capture_exception).once.with(Mobile::ListFilter::FilterError, { level: 'error' })
        expect(Raven).to receive(:extra_context).with({ filters: params.to_unsafe_hash, list_models: ['PetResource'] })
        result, error = Mobile::ListFilter.matches(list, params)
        expect(result).to eq(list)
        expect(error.class).to eq(Mobile::ListFilter::FilterError)
        expect(error.message).to eq('invalid filter structure')
      end

      it 'logs an error and returns original list when the filter contains multiple operations' do
        params = paramiterize({ genus: { eq: 'dog', not_eq: 'cat' } })

        expect(Raven).to receive(:capture_exception).once.with(Mobile::ListFilter::FilterError, { level: 'error' })
        expect(Raven).to receive(:extra_context).with({ filters: params.to_unsafe_hash, list_models: ['PetResource'] })
        result, error = Mobile::ListFilter.matches(list, params)
        expect(result).to eq(list)
        expect(error.class).to eq(Mobile::ListFilter::FilterError)
        expect(error.message).to eq('invalid filter structure')
      end

      it 'logs an error and returns original list when the requested filter operation is not supported' do
        params = paramiterize({ species: { fuzzyEq: 'dog' } })

        expect(Raven).to receive(:capture_exception).once.with(Mobile::ListFilter::FilterError, { level: 'error' })
        expect(Raven).to receive(:extra_context).with({ filters: params.to_unsafe_hash, list_models: ['PetResource'] })
        result, error = Mobile::ListFilter.matches(list, params)
        expect(result).to eq(list)
        expect(error.class).to eq(Mobile::ListFilter::FilterError)
        expect(error.message).to eq('invalid operation')
      end

      it 'logs an error and returns list when an unexpected error occurs' do
        params = paramiterize({})
        allow_any_instance_of(Mobile::ListFilter).to receive(:matches).and_raise(StandardError)

        expect(Raven).to receive(:capture_exception).once.with(StandardError, { level: 'error' })
        expect(Raven).to receive(:extra_context).with({ filters: params.to_unsafe_hash, list_models: ['PetResource'] })
        result, error = Mobile::ListFilter.matches(list, params)
        expect(result).to eq(list)
        expect(error.class).to eq(StandardError)
        expect(error.message).to eq('StandardError')
      end
    end
  end
end
