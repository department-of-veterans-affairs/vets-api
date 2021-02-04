# frozen_string_literal: true

require 'common/models/base'
require_relative 'nearby_facility'

module Lighthouse
  module Facilities
    class NearbyResponse < Common::Base
      attribute :body, String
      attribute :current_page, Integer
      attribute :data, Object
      attribute :links, Object
      attribute :meta, Object
      attribute :per_page, Integer
      attribute :status, Integer
      attribute :total_entries, Integer

      def initialize(body, status)
        super()
        self.body = body
        self.status = status
        parsed_body = JSON.parse(body)
        self.data = parsed_body['data']
        self.meta = parsed_body['meta']
        self.links = parsed_body['links']
        # This endpoint is not currently responding with a JSONAPI meta element
      end

      def facilities
        data.map do |facility|
          Lighthouse::Facilities::NearbyFacility.new(facility)
        end
      end
    end
  end
end
