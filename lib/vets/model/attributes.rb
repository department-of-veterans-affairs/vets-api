# frozen_string_literal: true

require 'vets/model/attributes/value'

module Vets
  module Model
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
          attributes.select { |_, options| options[:filterable] }.keys
        end

        # Creates a param hash for filterable
        def filterable_params
          attributes.each_with_object({}) do |attribute, hash|
            name = attribute.first
            options = attribute.second

            hash[name.to_s] = options[:filterable] if options[:filterable]
          end.with_indifferent_access
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
            casted_value = Vets::Model::Attributes::Value.cast(name, klass, value, array:)
            instance_variable_set("@#{name}", casted_value)
            casted_value
          end
        end
      end
    end
  end
end
