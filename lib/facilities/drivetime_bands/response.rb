# frozen_string_literal: true

require 'common/models/base'

module Facilities
  module DrivetimeBands
    class Response < Common::Base
      attribute :body, String

      def initialize(body)
        self.body = body
      end

      def parse_json
        JSON.parse(body)
      end

      def get_features(json_parsed_body)
        json_parsed_body['features']
      end
    end
  end
end
