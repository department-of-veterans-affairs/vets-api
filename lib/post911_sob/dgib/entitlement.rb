# frozen_string_literal: true

require 'common/models/base'

module Post911SOB
  module DGIB
    class Entitlement < Common::Base
      attribute :months, Integer
      attribute :days, Integer

      def initialize(days)
        attributes = {
          months: days / 30,
          days: days % 30
        }
        super(attributes)
      end
    end
  end
end
