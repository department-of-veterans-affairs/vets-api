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
        gi_response.status = RESPONSE_STATUS[:ok]
        gi_response.body = response.body
        gi_response
      end

      def cache?
        ok? || not_found?
      end

      def ok?
        @status == RESPONSE_STATUS[:ok]
      end
    end
  end
end
