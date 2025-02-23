# frozen_string_literal: true

require 'vets/model/type/base'

module Vets
  module Model
    module Type
      class HTTPDate < Base
        def self.primitive
          ::String
        end

        def cast(value)
          return nil if value.nil?

          Time.parse(value.to_s).utc.httpdate
        rescue ArgumentError
          raise TypeError, "#{@name} is not Time parseable"
        end
      end
    end
  end
end
