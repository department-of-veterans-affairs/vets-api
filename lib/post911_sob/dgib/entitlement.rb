# frozen_string_literal: true

require 'common/models/base'

module Post911SOB
  module DGIB
    class Entitlement < Common::Base
      attribute :months, Integer
      attribute :days, Integer

      def initialize(attributes)
        # TO-DO: Logic to parse months, days from integer amount (if necessary)
      end
    end
  end
end
