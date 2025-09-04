# frozen_string_literal: true

require 'vets/model'

# Model for responses from Lighthouse facilities "nearby" endpoint which
# only returns facility ID and drivetime band information, and for health
# facilities only
module Lighthouse
  module Facilities
    class NearbyFacility
      include Vets::Model

      attribute :id, String
      attribute :min_time, Integer
      attribute :max_time, Integer

      def initialize(fac)
        super(fac)

        @id = fac['id']
        @min_time = fac['attributes']['min_time']
        @max_time = fac['attributes']['max_time']
      end
    end
  end
end
