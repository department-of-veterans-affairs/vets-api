# frozen_string_literal: true

require 'bid/configuration'

module BID
  module Awards
    class Configuration < BID::Configuration
      def base_path
        "#{Settings.bid.awards.base_url}/api/v1/awards/"
      end

      def service_name
        'BID/Awards'
      end

      def request_headers
        {
          Authorization: "Bearer #{Settings.bid.awards.credentials}"
        }
      end

      def mock_enabled?
        Settings.bid.awards.mock || false
      end
    end
  end
end
