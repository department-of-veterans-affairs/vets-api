# frozen_string_literal: true

require 'common/models/base'

module Facilities
  module DrivetimeBands
    class Response < Common::Base
      attribute :body, String

      def initialize(body)
        self.body = body
      end

      def get_features
        JSON.parse(body)['features']
      end
    end
  end
end
