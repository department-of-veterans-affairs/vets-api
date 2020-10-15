# frozen_string_literal: true

module Facilities
  module PPMS
    # ppms has strange behavior for certain url-encoded characters, no url-encoding works best
    class DoNotEncoder
      def self.encode(params)
        buffer = +''
        params.each do |key, value|
          buffer << "#{key}=#{value}&"
        end
        buffer.chop
      end
    end
  end
end
