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
    end

    class Uploader
      def track_upload_begun
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
