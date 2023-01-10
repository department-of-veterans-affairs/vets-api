# frozen_string_literal: true

module Mobile
  class ListFilter
    include SentryLogging

    class FilterError < StandardError
    end

    PERMITTED_OPERATIONS = %w[eq notEq].freeze

    def initialize(collection, filter_params)
      @collection = collection
      @filter_params = filter_params
    end

    # Accepts params:
    #   @collection - a Common::Collection of Common::Base models
    #   @filter_params - should be an ActionController::Parameters object which should be passed in from the
    #     controller via @params[:filter]. This will pass in another ActionController::Parameters object.
    # Returns: a new Common::Collection of Common::Base models that match the provided filters
    def self.matches(collection, filter_params)
      filterer = new(collection, filter_params)
      filterer.result
    end

    def result
      validate!
      metadata = @collection.metadata.merge(filter: filters)
      Common::Collection.new(data: matches, metadata: metadata, errors: @collection.errors)
    rescue FilterError => e
      @collection.errors[:filter_error] = e.message if valid_collection?
      log_exception_to_sentry(e, extra_context_for_errors)
      @collection
    rescue => e
      @collection.errors[:filter_error] = 'unknown filter error'
      log_exception_to_sentry(e, extra_context_for_errors)
      @collection
    end

    # not adding full collection to extra context because it could be a large amount of data,
    # could expose PII, and isn't likely to be relevant
    def extra_context_for_errors
      extra_context = {}
      extra_context[:filters] = filters if filter_is_parameters?
      extra_context[:collection_models] = filterable_models.map(&:to_s) if valid_collection?
      extra_context
    end

    private

    def matches
      @collection.data.select { |record| record_matches_filters?(record) }
    end

    def record_matches_filters?(record)
      filters.all? do |match_attribute, operations_and_values|
        match_attribute = match_attribute.to_sym
        model_attribute = model_attributes.find { |att| att.name == match_attribute }
        coercer = model_attribute.coercer

        operations_and_values.each_pair.all? do |operation, value|
          coerced_value = coercer.call(value)

          case operation.to_sym
          when :eq
            record[match_attribute] == coerced_value
          when :notEq
            record[match_attribute] != coerced_value
          end
        end
      end
    end

    def validate!
      raise FilterError, 'list must be a Common::Collection' unless valid_collection?
      raise FilterError, 'collection contains multiple models' unless collection_contains_single_model?
      raise FilterError, 'filters must be an ActionController::Parameters' unless filter_is_parameters?
      raise FilterError, 'invalid filter structure' unless valid_filter_structure?
      raise FilterError, 'invalid attribute' unless valid_filter_attributes?
      raise FilterError, 'invalid operation' unless valid_filter_operations?
    end

    def valid_collection?
      @collection.is_a?(Common::Collection)
    end

    def collection_contains_single_model?
      filterable_models.count == 1
    end

    def filter_is_parameters?
      @filter_params.is_a?(ActionController::Parameters)
    end

    # this will likely change as our requirements evolve, but for now we can safely
    # limit to one operation/value pair per attribute
    def valid_filter_structure?
      operation_value_pairs.all? do |pair|
        pair.is_a?(Hash) && pair.count == 1
      end
    end

    def valid_filter_attributes?
      filter_attributes.all? { |key| key.to_sym.in? model_attributes.map(&:name) }
    end

    def valid_filter_operations?
      operations.all? { |operation| operation.in? PERMITTED_OPERATIONS }
    end

    def filterable_model
      filterable_models.first
    end

    def filterable_models
      @filterable_model ||= @collection.data.map(&:class).uniq
    end

    def model_attributes
      filterable_model.attribute_set
    end

    # to_unsafe_hash is only unsafe in the context of mass assignment as part of the strong params pattern
    def filters
      @filter_params.to_unsafe_hash
    end

    def filter_attributes
      filters.keys
    end

    def operation_value_pairs
      filters.values
    end

    def operations
      operation_value_pairs.map(&:keys).flatten.uniq
    end
  end
end
