# frozen_string_literal: true
require 'singleton'

module Common
  module Client
    class Configuration
      include Singleton

      OPEN_TIMEOUT = 15
      READ_TIMEOUT = 15
      REQUEST_TYPES = %i(get put post delete).freeze
      USER_AGENT = 'Vets.gov Agent'
      BASE_REQUEST_HEADERS = {
        'Accept' => 'application/json',
        'Content-Type' => 'application/json',
        'User-Agent' => USER_AGENT
      }.freeze

      def base_path
        raise NotImplementedError, 'Subclass of Configuration must implement base_path'
      end

      def open_timeout
        OPEN_TIMEOUT
      end

      def read_timeout
        READ_TIMEOUT
      end

      def request_types
        REQUEST_TYPES
      end

      def base_request_headers
        BASE_REQUEST_HEADERS
      end

      def request_options
        {
          open_timeout: open_timeout,
          timeout: read_timeout
        }
      end
    end
  end
end
