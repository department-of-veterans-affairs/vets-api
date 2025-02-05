# frozen_string_literal: true

require 'gi/gids_response'

module GI
  module LCPE
    class Response < GI::GIDSResponse
    # @return  [Integer] the LCPE data version
    attribute :version, Integer

    # Builds a response with a ok status, response's body, and version of LCPE data
    #
    # @param response returned from the rest call
    # @return [GI::LCPE::Response]
    def self.from(response)
      version = response.body.delete(:version)
      Response.new(status: response.status, body: response.body, version:)
    end
    end
  end
end
