# frozen_string_literal: true

# This will be moved after virtus is removed
module Bool; end
class TrueClass; include Bool; end
class FalseClass; include Bool; end

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
      # class variable attributes won't work so this is
      # the only way for it to work. Thread safety shouldn't
      # matter because @attributes is the same across all thread
      # they are set by the class.
      # rubocop:disable ThreadSafety/InstanceVariableInClassMethod
      def attributes
        @attributes ||= {}
      end
      # rubocop:enable ThreadSafety/InstanceVariableInClassMethod

      # Class method to define a setter & getter for attribute
      # this will also coerce a hash to the require class
      # doesn't currently coerce scalar classes such as string to int
      # In the future this could become it's own class e.g., Vets::Model::Attribute
      #
      # @param name [Symbol] the name of the attribute
      # @param klass [Class] the class of the attribute
      # @param default [String|Integer] the default value of the attribute
      #
      def attribute(name, klass, **options)
        default = options[:default]
        array = options[:array] || false

        attributes[name] = { type: klass, default:, array: }

        define_getter(name, default)
        define_setter(name, klass, array)
      end

      def attribute_set
        attributes.keys
      end

      private

      def define_getter(name, default)
        define_method(name) do
          instance_variable_get("@#{name}") || begin
            return nil unless defined?(default)

            if default.is_a?(Symbol) && respond_to?(default)
              send(default)
            else
              default
            end
          end
        end
      end

      def define_setter(name, klass, array)
        define_method("#{name}=") do |value|
          if array
            raise TypeError, "#{name} must be an Array" unless value.is_a?(Array)

            value = value.map do |item|
              item.is_a?(Hash) ? klass.new(item) : item
            end

            unless value.all? { |item| item.is_a?(klass) }
              raise TypeError, "All elements of #{name} must be of type #{klass}"
            end
          end

          value = ActiveModel::Type::Boolean.new.cast(value) if klass == Boolean

          value = klass.new(value) if value.is_a?(Hash)

          if (array && value.is_a?(Array)) || value.is_a?(klass) || value.nil?
            instance_variable_set("@#{name}", value)
          else
            raise TypeError, "#{name} must be a #{klass}"
          end
        end
      end
    end

    def initialize(params = {})
      super
      # Ensure all attributes have a defined value (default to nil)
      self.class.attribute_set.each do |attr_name|
        instance_variable_set("@#{attr_name}", nil) unless instance_variable_defined?("@#{attr_name}")
      end
    end

    # Acts as ActiveRecord::Base#attributes which is needed for serialization
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
        if value.respond_to?(:attributes)
          nested_attributes(value.instance_values)
        else
          value
        end
      end
    end
  end
end
