# frozen_string_literal: true

require 'logging/monitor'

module ClaimsEvidenceApi
  # @see Logging::BaseMonitor
  class Monitor < ::Logging::Monitor
    def initialize
      super('claims-evidence-api')
    end

    # utility function, @see Rails.logger
    #
    # @param msg [Mixed] the message to be logged
    #
    # @return [String] the formatted message, preceded with the monitor class name
    def format_message(msg)
      this = self.class.name
      format('%<class>s: %<msg>s', { class: this, msg: msg.to_s })
    end

    # utility function to format metric tags for DataDog
    #
    # @param tags [Hash] key-value pairs for metric tags
    #
    # @return [Array<String>] an array of string; eg. ["key:value" ...]
    def format_tags(tags)
      tags.map { |key, value| "#{key}:#{value}" }
    end

    class Record < Monitor
      METRIC = 'module.claims_evidence_api.service.record'

      attr_reader :record

      def initialize(record)
        super
        @record = record
      end

      def track_event(action, **attributes)
        message = format_message("#{record.class} #{action}")
        tags = format_tags({ class: record.class.to_s.downcase.gsub(/:+/, '_'), action: })

        track_request(:info, message, METRIC, tags:, **attributes)
      end
    end

    class Service < Monitor
      METRIC = 'module.claims_evidence_api.service.request'

      def track_api_request(method, path, code, reason, call_location: nil)
        call_location ||= caller_locations.first

        message = format_message(reason)
        tags = { method:, code:, reason:, route_root: path.split('/').first }
        level = /^2\d{2,}$/.match?(code.to_s.strip) ? :info : :error

        track_request(level, message, METRIC, call_location:, tags: format_tags(tags), **tags)
      end
    end

    class Uploader < Monitor
      METRIC = 'module.claims_evidence_api.uploader'

      def track_upload_begun(**context)
        message = format_message('upload begun')
        tags = format_tags({ action: 'begun' })

        track_request(:info, message, METRIC, call_location:, tags:, **context)
      end

      def track_upload_attempt(**context)
        message = format_message('upload attempt')
        tags = format_tags({ action: 'attempt' })

        track_request(:info, message, METRIC, call_location:, tags:, **context)
      end

      def track_upload_success(**context)
        message = format_message('upload success')
        tags = format_tags({ action: 'success' })

        track_request(:info, message, METRIC, call_location:, tags:, **context)
      end

      def track_upload_failure(error_message, **context)
        message = format_message("upload failure - ERROR #{error_message}")
        tags = format_tags({ action: 'failure' })

        track_request(:error, message, METRIC, call_location:, tags:, **context)
      end

      private

      # return the location which is calling the monitor function
      def call_location
        caller_locations.second
      end
    end
  end
end
