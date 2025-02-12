# frozen_string_literal: true

require 'gi/gids_response'

module GI
  module LCPE
    class Response < GIDSResponse
      attr_accessor :version

      # Builds a response with a ok status and a response's body
      #
      # @param response returned from the rest call
      # @return [GI::LCPE::Response]
      def self.from(response)
        version = response.response_headers[:etag]
        new(status: response.status, body: response.body.merge(version:))
      end
    end
  end
end
