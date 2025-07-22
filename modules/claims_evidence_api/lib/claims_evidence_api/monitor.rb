# frozen_string_literal: true

require 'logging/monitor'

module ClaimsEvidenceApi
  # @see Logging::BaseMonitor
  class Monitor < ::Logging::Monitor

    # constructor
    def initialize
      super('claims-evidence-api')
    end

    class Service
      def initialize(service_route)
        @service_route = service_route
      end

      def track_api_request(method, path, response, call_location: nil)
        metric = 'module.claims_evidence_api.request'
        #track_request(error_level, message, metric, call_location: nil, **context)
      end
    end

    class Uploader
      def track_upload_begin
      end

      def track_upload_attempt
      end

      def track_upload_success
      end

      def track_upload_failure
      end
    end

  end
end
