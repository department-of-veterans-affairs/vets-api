module Vets
  module Attributes
    class Value

      def self.cast(name, klass, value, array: false)
        new((name, klass, value, array)).setter_value(value)
      end

      def initialize(name, klass, array: false)
        @name = name
        @klass_type = klass_type
        @array = array
      end

      def setter_value(value)
        validate_array(value) if @array
        value = cast_boolean(value) if @klass_type == Boolean
        value = coerce_to_class(value)
        validate_type(value)
        value
      end

      private

      def validate_array(value)
        raise TypeError, "#{@name} must be an Array" unless value.is_a?(Array)

        value.map! do |item|
          item.is_a?(Hash) ? @klass_type.new(item) : item
        end

        unless value.all? { |item| item.is_a?(@klass_type) }
          raise TypeError, "All elements of #{@name} must be of type #{@klass_type}"
        end
      end

      def cast_boolean(value)
        ActiveModel::Type::Boolean.new.cast(value)
      end

      def coerce_to_class(value)
        value.is_a?(Hash) ? @klass_type.new(value) : value
      end

      def validate_type(value)
        if (@array && value.is_a?(Array)) || value.is_a?(@klass_type) || value.nil?
          return
        end
        raise TypeError, "#{@name} must be a #{@klass_type}"
      end
    end
  end
end
