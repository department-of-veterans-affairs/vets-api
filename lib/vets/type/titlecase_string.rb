# frozen_string_literal: true

require 'vets/type/base'

module Vets
  module Type
    class TitlecaseString < Base
      def cast(value)
        return nil if value.nil?

        value.downcase.titlecase
      end
    end
  end
end
