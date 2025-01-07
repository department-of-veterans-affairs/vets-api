# frozen_string_literal: true

require 'vets/type/base'

module Vets
  module Type
    class ISO8601Time < Base
      def self.primitive
        ::String
      end

      def cast(value)
        return nil if value.nil?

        Time.iso8601(value)
      rescue ArgumentError
        raise TypeError, "#{@name} is not iso8601"
      end
    end
  end
end
