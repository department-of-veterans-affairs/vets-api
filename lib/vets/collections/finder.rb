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

      attr_reader :data, :filterable_attribute

      def initialize(data:)
        @data = data
        @model_class = data.first.class
        @filterable_attribute = @model_class.filterable_attributes
      end

      def all(conditions)
        validate_conditions(conditions)
        @data.select { |item| finder(item, conditions) }
      end

      def first(conditions)
        validate_conditions(conditions)
        @data.detect { |item| finder(item, conditions) }
      end

      private

      def validate_conditions(conditions)
        # Validate attributes are filterable
        failed_attributes = (conditions.keys.map(&:to_s) - @filterable_attributes.keys).join(', ')
        raise Common::Exceptions::FilterNotAllowed, failed_attributes unless failed_attributes.empty?

        # Validate the operations are valid for each attribute
        conditions.each do |attribute, predicates|
          predicates.each_key do |operation|
            valid_operation = @filterable_attributes[attribute].include?(operation.to_s)
            message = "#{operation} for #{attribute}"
            raise Common::Exceptions::FilterNotAllowed, message unless valid_operation
          end
        end
      end

      # operation means eq, lteq, etc
      # operator means ==, <=
      def compare(object, conditions)
        conditions.to_hash.all? do |attribute, predicates|
          predicates.all? do |operation, value|
            object_value = object.send(attribute)
            operator = OPERATIONS_MAP.fetch(operation)

            parsed_values = value.try(:split, ',') || [value]
            results = parsed_values.map do |item|
              if operator == 'match'
                object_value.to_s.match?(value.to_s)
                object_value.downcase.include?(item.downcase)
              else
                object_value.public_send(operator, value)
              end
            end
            results.any?
          end
        end
      rescue
        raise Common::Exceptions::InvalidFiltersSyntax.new(nil, detail: 'The syntax for your filters is invalid')
      end
    end
  end
end
