# frozen_string_literal: true

require 'vets/attributes/value'

module Vets
  module Attributes
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def attributes
        @attributes ||= {} # rubocop:disable ThreadSafety/ClassInstanceVariable
      end

      def attribute(name, klass, **options)
        default = options[:default]
        array = options[:array] || false
        filterable = options[:filterable] || false

        attributes[name] = { type: klass, default:, array:, filterable: }

        define_getter(name, default)
        define_setter(name, klass, array)
      end

      def attribute_set
        # grabs attribute keys from parent classes
        ancestors.select { |klass| klass.respond_to?(:attributes) }.flat_map { |klass| klass.attributes.keys }.uniq
      end

      # Lists the attributes that are filterable
      def filterable_attributes
        ancestors.select { |klass| klass.respond_to?(:attributes) }.flat_map do |klass|
          klass.attributes.select { |_, options| options[:filterable] }.keys
        end
      end

      # Creates a param hash for filterable
      def filterable_params
        ancestors
          .select { |klass| klass.respond_to?(:attributes) }
          .each_with_object({}.with_indifferent_access) do |klass, result|
            klass.attributes.each do |name, options|
              result[name.to_s] = options[:filterable] if options[:filterable]
            end
          end
      end

      private

      def define_getter(name, default)
        define_method(name) do
          # check if the attribute is assigned and not nil
          if instance_variable_defined?("@#{name}")
            value = instance_variable_get("@#{name}")
            return value unless value.nil?
          end

          # if value is nil check for a default
          return nil unless defined?(default)

          # if there's a default, assign the default value
          if default.is_a?(Symbol) && respond_to?(default)
            send(default)
          else
            default
          end
        end
      end

      def define_setter(name, klass, array)
        define_method("#{name}=") do |value|
          casted_value = Vets::Attributes::Value.cast(name, klass, value, array:)
          instance_variable_set("@#{name}", casted_value)
          casted_value
        end
      end
    end
  end
end
