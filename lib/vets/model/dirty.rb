# frozen_string_literal: true

# Intended to only be used with Vets::Model
# inspired by ActiveModel::Dirty

module Vets
  module Model
    module Dirty
      def initialize(*, **)
        super(*, **) if defined?(super)
        @original_attributes = attribute_values.dup
      end

      def changed?
        changes.any?
      end

      def changed
        changes.keys
      end

      def changes
        attribute_values.each_with_object({}) do |(key, current_value), result|
          original_value = @original_attributes[key]
          result[key] = [original_value, current_value] if original_value != current_value
        end
      end

      attr_reader :original_attributes
    end
  end
end
