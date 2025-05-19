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

        value if value.is_a?(::String) && Time.parse(value).iso8601
      rescue ArgumentError
        nil
      end
    end
  end
end
