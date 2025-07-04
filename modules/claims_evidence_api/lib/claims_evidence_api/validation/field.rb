# frozen_string_literal: true

module ClaimsEvidenceApi
  module Validation
    # parent class for containing field level validations
    class BaseField
      # valid types of fields
      TYPES = %i[string integer number boolean].freeze

      attr_reader :type, :validations

      # create a field validator of `type` with the supplied validations
      #
      # @example BaseField.new(type: :integer, min: 1, max: 50)
      #
      # @raise ArgumentError if type is not in TYPES
      def initialize(type:, **validations)
        @type = type.to_s.downcase.to_sym
        raise ArgumentError unless TYPES.include?(@type)

        @validations = validations
      end

      # validate a field value against the set of validations fot _this_ field
      #
      # @param value [Mixed] the value to be validated
      def validate(value)
        value = transform_value(value)

        validations.each { |func, arg| send(func, arg, value) }

        value
      end

      private

      # check if the value is greater or equal to min
      # if type is :string the length of value is checked
      #
      # @raise ArgumentError if value < min
      #
      # @param min [Number] the minimum for value
      # @param value [Mixed] the value to test
      def minimum(min, value)
        case type
        when :string
          raise ArgumentError unless value.length >= min
        when :integer, :number
          raise ArgumentError unless value >= min
        end
      end

      # check if the value is less or equal to max
      # if type is :string the length of value is checked
      #
      # @raise ArgumentError if value > min
      #
      # @param max [Number] the maximum for value
      # @param value [Mixed] the value to test
      def maximum(max, value)
        case type
        when :string
          raise ArgumentError unless value.length <= max
        when :integer, :number
          raise ArgumentError unless value <= max
        end
      end

      # check if the value matches the desired pattern
      # if type is :string the length of value is checked
      #
      # @raise ArgumentError if value does not match regex
      #
      # @param regex [String|Regex] the pattern for value
      # @param value [Mixed] the value to test
      def pattern(regex, value)
        raise ArgumentError, '`type` must be :string to use pattern' if type != :string
        raise ArgumentError, "#{value} is not a string" if value.class != String
        raise ArgumentError, "#{value} does not match #{regex}" unless regex.match?(value)
      end

      # check if the value is in an accepted set
      # if type is :string the length of value is checked
      #
      # @raise ArgumentError if value is not in accepted
      #
      # @param accepted [Array<Mixed>] the accepted values
      # @param value [Mixed] the value to test
      def enum(accepted, value)
        raise ArgumentError, "#{value} must be one of #{accepted}" unless accepted.include?(value)
      end

      # transform the value to the appropriate type for _this_ field
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

    # String subclass
    class StringField < BaseField
      def initialize(**validations)
        super(type: :string, **validations)
      end
    end

    # Integer subclass
    class IntegerField < BaseField
      def initialize(**validations)
        super(type: :integer, **validations)
      end
    end

    # Number subclass
    class NumberField < BaseField
      def initialize(**validations)
        super(type: :number, **validations)
      end
    end

    # Boolean subclass
    class BooleanField < BaseField
      def initialize
        super(type: :boolean)
      end
    end

    # end Validations
  end

  # end ClaimsEvidenceApi
end
