# frozen_string_literal: true

require 'common/models/redis_store'
require 'common/client/concerns/service_status'
require 'mvi/models/mvi_profile'

module GI
  module Responses
    class GIDSResponse
      include Virtus.model(nullify_blank: true)

      # @return  [Integer] the response status
      attribute :status, Integer

      # @return  [Hash] the response body
      attribute :body, Hash

      # Builds a response with a ok status and a response's body
      #
      # @param response returned from the rest call
      # @return [GI::Responses::GIDSResponse]
      def self.from(response)
        GIDSResponse.new(status: response.status, body: response.body)
      end

      def cache?
        @status == 200
      end
    end
  end
end
