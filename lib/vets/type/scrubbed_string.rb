# frozen_string_literal: true

require 'vets/type/base'

module Vets
  module Type
    class ScrubbedString < Base
      def self.primitive
        ::String
      end

      def cast(value)
        return nil if value.nil?

        ['NONE'].include?(value.to_s.upcase) ? '' : value
      end
    end
  end
end
