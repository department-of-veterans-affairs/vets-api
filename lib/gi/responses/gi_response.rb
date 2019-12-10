# frozen_string_literal: true

require 'common/models/redis_store'
require 'common/client/concerns/service_status'
require 'mvi/models/mvi_profile'

module GI
  module Responses
    class GiResponse
      include Common::Client::ServiceStatus

      attr_accessor :status, :body

      # Builds a response with a ok status and a response's body
      #
      # @param response returned from the rest call
      # @return [GI::Responses::GiResponse]
      def self.with_body(response)
        gi_response = GiResponse.new
        gi_response.status = response.status
        gi_response.body = response.body
        gi_response
      end

      def cache?
        false
        # @status == 200
      end
    end
  end
end
