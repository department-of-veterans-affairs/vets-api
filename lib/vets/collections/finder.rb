# frozen_string_literal: true

require 'common/exceptions/base_error'
require 'common/exceptions/filter_not_allowed'
require 'common/exceptions/invalid_filters_syntax'

module Vets
  module Collections
    class Finder
      OPERATIONS_MAP = {
        'eq' => '==',
        'lteq' => '<=',
        'gteq' => '>=',
        'not_eq' => '!=',
        'match' => 'match'
      }.with_indifferent_access.freeze

      attr_reader :data, :filterable_attributes

      def initialize(data:)
        @data = data
        @model_class = data.first.class
        @filterable_attributes = @model_class.filterable_attributes
        @filterable_params = @model_class.filterable_params
      end

      def all(conditions)
        validate_conditions(conditions)
        @data.select { |item| compare(item, conditions) }
      end

      def first(conditions)
        validate_conditions(conditions)
        @data.detect { |item| compare(item, conditions) }
      end

      private

      def validate_conditions(conditions)
        # Validates conditions aren't nil or blank
        raise Common::Exceptions::InvalidFiltersSyntax, 'Filters must be present' if conditions.blank?

        # Validate attributes are filterable
        failed_attributes = (conditions.keys.map(&:to_s) - @filterable_attributes.map(&:to_s)).join(', ')
        raise Common::Exceptions::FilterNotAllowed, failed_attributes unless failed_attributes.empty?

        # Validate the operations are valid for each attribute
        conditions.each do |attribute, predicates|
          predicates.each_key do |operation|
            valid_operation = @filterable_params[attribute].include?(operation.to_s)
            message = "#{operation} for #{attribute}"
            raise Common::Exceptions::FilterNotAllowed, message unless valid_operation
          end
        end
      end

      # operation means eq, lteq, etc
      # operator means ==, <=
      def compare(object, conditions)
        conditions.to_hash.all? do |attribute, predicates|
          predicates.all? do |operation, operand|
            object_value = object.public_send(attribute)
            operator = OPERATIONS_MAP.fetch(operation)

            parsed_values = operand.try(:split, ',') || [operand]
            results = parsed_values.map do |value|
              if operator == 'match'
                object_value.downcase.include?(value.downcase)
              else
                object_value.public_send(operator, value)
              end
            end
            results.any?
          end
        end
      rescue => e
        message = "The syntax for your filters is invalid: #{e.message}"
        raise Common::Exceptions::InvalidFiltersSyntax, message
      end
    end
  end
end
