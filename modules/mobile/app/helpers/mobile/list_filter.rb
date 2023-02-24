# frozen_string_literal: true

module Mobile
  class ListFilter
    include SentryLogging

    class FilterError < StandardError
    end

    PERMITTED_OPERATIONS = %w[eq not_eq].freeze

    def initialize(list, filter_params)
      @list = list
      @filter_params = filter_params
    end

    # Accepts params:
    #   @list - an array of Common::Resource or Common::Base models
    #   @filter_params - should be an ActionController::Parameters object which should be passed in from the
    #     controller via @params[:filter]. This will pass in another ActionController::Parameters object.
    # Returns an array containing:
    #   an array of Common::Resource or Common::Base models that match the provided filters
    #   a hash of any errors encountered or nil if no errors were encountered
    def self.matches(list, filter_params)
      filterer = new(list, filter_params)
      filterer.result
    end

    def result
      return [@list, nil] if @filter_params.nil?

      validate!
      [matches, nil]
    rescue => e
      log_exception_to_sentry(e, extra_context_for_errors)
      [@list, e]
    end

    def extra_context_for_errors
      extra_context = {}
      extra_context[:filters] = filters if filter_is_parameters?
      extra_context[:list_models] = filterable_models.map(&:to_s) if valid_list?
      extra_context
    end

    private

    def matches
      @list.select { |record| record_matches_filters?(record) }
    end

    def record_matches_filters?(record)
      filters.all? do |match_attribute, operations_and_values|
        match_attribute = match_attribute.to_sym

        operations_and_values.each_pair.all? do |operation, value|
          case operation.to_sym
          when :eq
            record[match_attribute].to_s == value
          when :not_eq
            record[match_attribute].to_s != value
          end
        end
      end
    end

    def validate!
      raise FilterError, 'list must be an array' unless valid_list?
      raise FilterError, 'list contains multiple data types' unless list_contains_single_type?
      raise FilterError, 'list items must be Common::Resource or Common::Base models' unless list_composed_of_models?
      raise FilterError, 'filters must be an ActionController::Parameters' unless filter_is_parameters?
      raise FilterError, 'invalid filter structure' unless valid_filter_structure?
      raise FilterError, 'invalid attribute' unless valid_filter_attributes?
      raise FilterError, 'invalid operation' unless valid_filter_operations?
    end

    def valid_list?
      @list.is_a?(Array)
    end

    def list_contains_single_type?
      filterable_models.count == 1
    end

    def list_composed_of_models?
      common_base? || common_resource?
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
      filter_attributes.all? { |key| key.to_sym.in?(model_attributes) }
    end

    def valid_filter_operations?
      operations.all? { |operation| operation.in?(PERMITTED_OPERATIONS) }
    end

    def filterable_model
      filterable_models.first
    end

    def filterable_models
      @filterable_model ||= @list.map(&:class).uniq
    end

    def common_base?
      filterable_model.ancestors.map(&:to_s).include?('Common::Base')
    end

    def common_resource?
      filterable_model.ancestors.map(&:to_s).include?('Common::Resource')
    end

    def model_attributes
      common_resource? ? filterable_model.attribute_names : filterable_model.attribute_set.map(&:name)
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
