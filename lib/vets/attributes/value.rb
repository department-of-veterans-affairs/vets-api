# frozen_string_literal: true

module Vets
  module Attributes
    class Value
      def self.cast(name, klass, value, array: false)
        new(name, klass, array:).setter_value(value)
      end

      def initialize(name, klass, array: false)
        @name = name
        @klass = klass
        @array = array
      end

      def setter_value(value)
        validate_array(value) if @array
        value = cast_boolean(value) if @klass == Bool
        value = coerce_to_class(value)
        validate_type(value)
        value
      end

      private

      def validate_array(value)
        raise TypeError, "#{@name} must be an Array" unless value.is_a?(Array)

        value.map! do |item|
          item.is_a?(Hash) ? @klass.new(item) : item
        end

        unless value.all? { |item| item.is_a?(@klass) }
          raise TypeError, "All elements of #{@name} must be of type #{@klass}"
        end
      end

      def cast_boolean(value)
        ActiveModel::Type::Boolean.new.cast(value)
      end

      def coerce_to_class(value)
        return value if value.is_a?(@klass) || value.nil?

        if @klass == DateTime
          begin
            value = DateTime.parse(value) if value.is_a?(String)
          rescue ArgumentError
            raise TypeError, "#{@name} could not be parsed into a DateTime"
          end
        end

        value.is_a?(Hash) ? @klass.new(value) : value
      end

      def validate_type(value)
        return if (@array && value.is_a?(Array)) || value.is_a?(@klass) || value.nil?

        raise TypeError, "#{@name} must be a #{@klass}"
      end
    end
  end
end
