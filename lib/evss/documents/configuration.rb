# frozen_string_literal: true
module EVSS
  module Documents
    class Configuration < EVSS::Configuration
      API_VERSION = Settings.evss.versions.documents
      # this service is only used from an async worker so long timeout is acceptable here
      DEFAULT_TIMEOUT = 180 # seconds

      def base_path
        "#{Settings.evss.url}/wss-document-services-web-#{API_VERSION}/rest/"
      end

      def service_name
        'EVSS/Documents'
      end
    end
  end
end
