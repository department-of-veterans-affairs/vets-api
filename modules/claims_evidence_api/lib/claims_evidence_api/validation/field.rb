# frozen_string_literal: true

module ClaimsEvidenceApi
  module Validation
    class BaseField
      TYPES = %i[string integer number boolean].freeze

      attr_reader :type, :validations

      def initialize(type:, **validations)
        @type = type.to_s.downcase.to_sym
        raise ArgumentError unless TYPES.include?(@type)

        @validations = validations
      end

      def validate(value)
        value = transform_value(value)

        validations.each { |func, arg| send(func, arg, value) }

        value
      end

      private

      def minimum(min, value)
        case type
        when :string
          raise ArgumentError unless value.length >= min
        when :integer, :number
          raise ArgumentError unless value >= min
        end
      end

      def maximum(max, value)
        case type
        when :string
          raise ArgumentError unless value.length <= max
        when :integer, :number
          raise ArgumentError unless value <= max
        end
      end

      def pattern(regex, value)
        raise ArgumentError, '`type` must be :string to use pattern' if type != :string
        raise ArgumentError, "#{value} is not a string" if value.class != String
        raise ArgumentError, "#{value} does not match #{regex}" unless regex.match?(value)
      end

      def enum(accepted, value)
        raise ArgumentError, "#{value} must be one of #{accepted}" unless accepted.include?(value)
      end

      def transform_value(value)
        case type
        when :string
          value.to_s
        when :integer
          value.to_i
        when :number
          value.to_f
        when :boolean
          !!value
        end
      end
    end

    class StringField < BaseField
      def initialize(**validations)
        super(type: :string, **validations)
      end
    end

    class IntegerField < BaseField
      def initialize(**validations)
        super(type: :integer, **validations)
      end
    end

    class NumberField < BaseField
      def initialize(**validations)
        super(type: :number, **validations)
      end
    end

    class BooleanField < BaseField
      def initialize(**_validations)
        super(type: :boolean)
      end
    end

    # end Validations
  end

  # end ClaimsEvidenceApi
end
