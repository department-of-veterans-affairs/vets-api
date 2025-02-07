# frozen_string_literal: true

require 'gi/configuration'

module GI
  module LCPE
    class Configuration < GI::Configuration
      attr_accessor :etag
      
      private

      def request_headers
        super unless etag

        base_request_headers.merge('If-None-Match' => etag)
      end
    end
  end
end
