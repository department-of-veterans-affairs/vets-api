# frozen_string_literal: true

require 'common/models/base'

module Lighthouse
  module Facilities
    class Response < Common::Base
      attribute :body, String
      attribute :status, Integer
      attribute :data, Object
      attribute :meta, Object

      def initialize(body, status)
        super()
        self.body = body
        self.status = status
        parsed_body = JSON.parse(body)
        self.data = parsed_body['data']
        self.meta = parsed_body['meta']
      end

      def get_facilities_list
        data.each_with_index.map do |facility, index|
          fac = Lighthouse::Facilities::Facility.new(facility)
          fac.distance = meta['distances'][index]['distance'] unless meta['distances'].empty?
          fac
        end
      end

      def new_facility
        Lighthouse::Facilities::Facility.new(data)
      end
    end
  end
end
