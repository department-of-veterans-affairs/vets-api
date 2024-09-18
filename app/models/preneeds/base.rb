# frozen_string_literal: true

# Parent class for other Preneeds Burial form related models
# Should not be initialized directly
#
module Preneeds
  class Base
    extend ActiveModel::Naming
    include ActiveModel::Model
    include ActiveModel::Serializers::JSON

    @attributes = {}.freeze

    class << self

      def attributes
        @attributes ||= {}
      end

      # Class method to define a setter & getter for attribute
      # this will also coerce a hash to the require class
      # doesn't currently coerce scalar classes such as string to int
      #
      # @param name [Symbol] the name of the attribute
      # @param klass [Class] the class of the attribute
      # @param default [String|Integer] the default value of the attribute
      #
      def attribute(name, klass, default: nil)
        attributes[name] = { type: klass, default: }

        # Define a getter method for the attribute
        define_method(name) do
          instance_variable_get("@#{name}") || default
        end

        # Define a setter method for the attribute
        define_method("#{name}=") do |value|
          value = klass.new(value) if value.is_a?(Hash)

          if value.is_a?(klass) || value.nil?
            instance_variable_set("@#{name}", value)
          else
            raise TypeError, "#{name} must be a #{klass}"
          end
        end
      end

      def attribute_set
        attributes.keys
      end
    end

    # Acts as ActiveRecord::Base#attributes which is needed
    # for serialization
    #
    def attributes
      nested_attributes(instance_values)
    end

    # Override `as_json`
    #
    # @param options [Hash]
    #
    # @see ActiveModel::Serializers::JSON
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
        if value.respond_to?(:instance_values)
          nested_attributes(value.instance_values)
        else
          value
        end
      end
    end
  end
end
