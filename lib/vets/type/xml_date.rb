# frozen_string_literal: true

require 'vets/type/base'

module Vets
  module Type
    class XmlDate < Base
      def self.primitive
        ::Time
      end

      def cast(value)
        return nil if value.nil?

        Time.iso8601(value.to_s).utc.strftime('%Y-%m-%d')
      rescue ArgumentError
        value
      end
    end
  end
end
