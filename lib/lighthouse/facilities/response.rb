# frozen_string_literal: true

require 'common/models/base'

module Lighthouse
  module Facilities
    class Response < Common::Base
      attribute :body, String
      attribute :status, Integer
      attribute :parsed_json, String
      attribute :data, Object

      def initialize(body, status)
        self.body = body
        self.status = status

        self.parsed_json = parse_json
        self.data = parsed_json['data']
      end

      def parse_json
        JSON.parse(body)
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
