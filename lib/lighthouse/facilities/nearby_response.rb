# frozen_string_literal: true

require 'vets/model'
require_relative 'nearby_facility'

module Lighthouse
  module Facilities
    class NearbyResponse
      include Vets::Model

      attribute :body, String
      attribute :current_page, Integer
      attribute :data, Hash, array: true
      attribute :links, Hash
      attribute :meta, Hash
      attribute :per_page, Integer
      attribute :status, Integer
      attribute :total_entries, Integer

      def initialize(body, status)
        super()
        @body = body
        @status = status
        parsed_body = JSON.parse(body)
        @data = Array.wrap(parsed_body['data']) # normalize data to array
        @meta = parsed_body['meta']
        @links = parsed_body['links']
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
