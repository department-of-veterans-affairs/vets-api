# frozen_string_literal: true

module Preneeds
  # Parent class for other Preneeds Burial form related models
  # Should not be initialized directly
  #
  class Base
    extend ActiveModel::Naming
    include ActiveModel::Model
    include ActiveModel::Serializers::JSON

    def self.attribute_set
      new.attributes.keys
    end

    # Acts as ActiveRecord::Base#attributes which is needed for serialization
    def attributes
      nested_attributes(instance_values)
    end

    # Override `as_json`
    #
    # @param options [Hash]
    # @see https://github.com/rails/rails/blob/49c613463b758a520a6162e702acc1158fc210ca/activesupport/lib/active_support/core_ext/object/json.rb#L46
    #
    def as_json(options = {})
      super(options).deep_transform_keys { |key| key.camelize(:lower) }
    end

    private

    # Collect values from attribute and nested objects
    #
    # @param values [Hash]
    #
    # @return [Hash] nested attributes
    def nested_attributes(values)
      values.transform_values do |value|
        if value.respond_to?(:attributes)
          nested_attributes(value.instance_values)
        else
          value
        end
      end
    end
  end
end
