# frozen_string_literal: true

require 'common/models/base'

module Facilities
  module DrivetimeBands
    class Response < Common::Base
      attribute :body, String
      attribute :parsed_json, String

      def initialize(body)
        self.body = body
        self.parsed_json = parse_json
      end

      def parse_json
        JSON.parse(body)
      end

      def get_features
        parsed_json['features']
      end
    end
  end
end
