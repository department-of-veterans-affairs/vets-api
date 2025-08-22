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
        return value if value.is_a?(String) && value.match?(/\d{4}-\d{2}-\d{2}T/)

        Time.iso8601(value)
      rescue ArgumentError
        raise TypeError, "#{@name} is not iso8601"
      end
    end
  end
end
