# frozen_string_literal: true

module Vets
  module Attributes
    def self.included(base)
      base.extend(ClassMethods)
      base.instance_variable_set(:@attributes, {})
    end

    module ClassMethods

      # rubocop:disable ThreadSafety/InstanceVariableInClassMethod
      def attributes
        @attributes
      end
      # rubocop:enable ThreadSafety/InstanceVariableInClassMethod

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
          Vets::Attributes::Value.cast(name, klass, value, array)
        end
      end
    end
  end
end
