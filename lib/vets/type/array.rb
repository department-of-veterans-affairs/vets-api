# frozen_string_literal: true

require 'vets/type/base'

module Vets
  module Type
    class Array < Base
      def initialize(name, klass, element_type)
        super(name, klass)
        @element_type = element_type
      end

      def cast(value)
        return nil if value.nil?

        raise TypeError, "#{@name} must be an Array" unless value.is_a?(::Array)

        value.map { |item| @element_type.cast(item) }
      end
    end
  end
end
