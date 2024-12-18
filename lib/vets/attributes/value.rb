# frozen_string_literal: true

module Vets
  module Attributes
    class Value

      def self.cast(name, klass, value, array: false)
        new(name, klass, array:).setter_value(value)
      end

      def initialize(name, klass, array: false)
        # Acts as a "type factory"
        @type = if array
          element_type = build(name, klass)
          Vets::Type::Array.new(name, ::Array, element_type)
        elsif Type::Primitive::PRIMITIVE_TYPES.include?(klass)
          Vets::Type::Primitive.new(name, klass)
        elsif klass < Vets::Attributes::Type
          Vets::Type.const_get(klass.name.demodulize).new(name)
        elsif klass.is_a?(Hash)
          Vets::Type::Hash.new(name)
        else
          Vets::Type::Object.new(name, klass)
        end
      end

      def setter_value(value)
        @type.cast(value)
      end
    end
  end
end
