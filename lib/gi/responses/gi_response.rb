# frozen_string_literal: true

require 'common/models/redis_store'
require 'common/client/concerns/service_status'
require 'mvi/models/mvi_profile'

module GI
  module Responses
    class GiResponse
      include Virtus.model(nullify_blank: true)
      include Common::Client::ServiceStatus

      attribute :status, Integer

      attribute :body, Hash

      # Builds a response with a ok status and a response's body
      #
      # @param response returned from the rest call
      # @return [GI::Responses::GiResponse]
      def self.with_body(response)
        GiResponse.new(status: response.status, body: response.body)
      end

      def cache?
        false
        # @status == 200
      end
    end
  end
end
