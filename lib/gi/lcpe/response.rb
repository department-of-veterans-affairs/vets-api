# frozen_string_literal: true

require 'gi/gids_response'

module GI
  module LCPE
    class Response < GIDSResponse
      # Builds a response with a ok status and a response's body
      #
      # @param response returned from the rest call
      # @return [GI::LCPE::Response]
      def self.from(response)
        version = response.response_headers['Etag'].match(%r{W/"(\d+)"})[1]
        new(status: response.status, body: response.body.merge(version:))
      end

      def version
        body[:version]
      end
    end
  end
end
