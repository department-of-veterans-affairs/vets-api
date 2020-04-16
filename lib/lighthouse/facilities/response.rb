# frozen_string_literal: true

require 'common/models/base'

module Lighthouse
  module Facilities
    class Response < Common::Base
      attribute :body, String
      attribute :status, Integer
      attribute :data, Object

      def initialize(body, status)
        super()
        self.body = body
        self.status = status
        self.data = JSON.parse(body)['data']
      end

      def get_facilities_list
        data.map do |facility|
          Lighthouse::Facilities::Facility.new(facility)
        end
      end

      def new_facility
        Lighthouse::Facilities::Facility.new(data)
      end
    end
  end
end
