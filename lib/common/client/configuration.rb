module Common
  module Client
    class Configuration
      REQUEST_TYPES = %i(get put post patch delete).freeze
      USER_AGENT = 'Vets.gov Agent'
      BASE_REQUEST_HEADERS = {
        'Accept' => 'application/json',
        'Content-Type' => 'application/json',
        'User-Agent' => USER_AGENT
      }.freeze

      def open_timeout
        15
      end

      def read_timeout
        15
      end

      def base_path
        raise NotImplementedError, 'Subclass of Configuration must implement base_path'
      end

      def request_options
        {
          open_timeout: open_timeout,
          timeout: read_timeout
        }
      end

      def request_types
        REQUEST_TYPES
      end

      def base_request_headers
        BASE_REQUEST_HEADERS
      end
    end
  end
end
