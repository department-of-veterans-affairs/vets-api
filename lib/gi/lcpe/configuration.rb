# frozen_string_literal: true

require 'active_support/rescuable'
require 'gi/configuration'

module GI
  module LCPE
    class Configuration < GI::Configuration
      attr_accessor :etag

      def set_etag(version)
        self.etag = "W/\"#{version}\""
      end

      private

      def request_headers
        return super unless etag

        base_request_headers.merge('If-None-Match' => etag)
      end
    end
  end
end
