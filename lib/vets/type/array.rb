# frozen_string_literal: true

require 'vets/types'

module Vets
  module Type
    class Array < Base
      def self.primitive
        ::Array
      end

      def cast(value)
        return nil if value.nil?

        raise TypeError, "#{@name} must be an Array" unless value.is_a?(::Array)

        casted_value = value.map { |item| type.cast(item) }

        unless casted_value.all? { |item| item.is_a?(@klass.try(:primitive) || @klass) }
          raise TypeError, "All elements of #{@name} must be of type #{@klass}"
        end

        casted_value
      end

      def type
        @type ||= if Vets::Type::Primitive::PRIMITIVE_TYPES.include?(@klass.name)
                    Vets::Type::Primitive.new(@name, @klass)
                  elsif @klass.module_parents.include?(Vets::Type)
                    @klass.new(@name, @klass)
                  elsif @klass == ::Hash
                    Vets::Type::Hash.new(@name)
                  else
                    Vets::Type::Object.new(@name, @klass)
                  end
      end
    end
  end
end
