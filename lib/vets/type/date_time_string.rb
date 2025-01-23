# frozen_string_literal: true

require 'vets/type/base'

module Vets
  module Type
    class DateTimeString < Base
      def self.primitive
        ::String
      end

      def cast(value)
        return nil if value.nil?

        Time.parse(value).iso8601
      rescue ArgumentError
        raise TypeError, "#{@name} is not Time parseable"
      end
    end
  end
end
