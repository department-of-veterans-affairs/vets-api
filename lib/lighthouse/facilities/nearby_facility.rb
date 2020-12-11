# frozen_string_literal: true

require 'common/models/base'
# Model for responses from Lighthouse facilities "nearby" endpoint which
# only returns facility ID and drivetime band information, and for health
# facilities only
module Lighthouse
  module Facilities
    class NearbyFacility < Common::Base
      include ActiveModel::Serializers::JSON

      attribute :id, String
      attribute :min_time, Integer
      attribute :max_time, Integer

      def initialize(fac)
        super(fac)

        self.id = fac['id']
        self.min_time = fac['attributes']['min_time']
        self.max_time = fac['attributes']['max_time']
      end
    end
  end
end
