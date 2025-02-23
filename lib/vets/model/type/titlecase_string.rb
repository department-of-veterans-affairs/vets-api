# frozen_string_literal: true

require 'vets/model/type/base'

module Vets
  module Model
    module Type
      class TitlecaseString < Base
        def self.primitive
          ::String
        end

        def cast(value)
          return nil if value.nil?

          value.to_s.downcase.titlecase
        end
      end
    end
  end
end
