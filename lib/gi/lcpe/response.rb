# frozen_string_literal: true

require 'gi/gids_response'

module GI
  module LCPE
    class Response < GIDSResponse
      # @return  [String] the latest LCPE data etag
      attribute :version, String
  
      # Builds a response with a ok status and a response's body
      #
      # @param response returned from the rest call
      # @return [GI::GIDSResponse]
      def self.from(response)
        version = response.response_headers['Etag']
        new(status: response.status, body: response.body, version: 4)
      end
    end
  end
end
