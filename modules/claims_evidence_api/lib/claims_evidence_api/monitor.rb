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

    # Monitor to be used within ActiveRecord models
    class Record < Monitor
      # StatsD metric
      METRIC = 'module.claims_evidence_api.service.record'

      attr_reader :record

      def initialize(record)
        super()
        @record = record
      end

      # track the action performed on a record
      #
      # @param action [String|Symbol] eg. create, update, delete
      # @param attributes [Mixed] named key-value pairs of record attributes
      def track_event(action, **attributes)
        message = format_message("#{record.class} #{action}")
        tags = format_tags({ class: record.class.to_s.downcase.gsub(/:+/, '_'), action: })

        track_request(:info, message, METRIC, tags:, **attributes)
      end
    end

    # Monitor to be used within Service classes
    class Service < Monitor
      # StatsD metric
      METRIC = 'module.claims_evidence_api.service.request'

      # track the api request performed and the response/error
      # @see Common::Client::Base#perform
      # @see Common::Client::Errors::ClientError
      #
      # @param method [String|Symbol] eg. get, post, put
      # @param path [String] the requested url path
      # @param code [Integer|String] the response code
      # @param reason [String] the response `reason_phrase`
      # @param call_location [Logging::CallLocation|Thread::Backtrace::Location] calling point to be logged
      def track_api_request(method, path, code, reason, call_location: nil)
        call_location ||= caller_locations.first

        message = format_message(reason)
        tags = { method:, code:, reason:, route_root: path.split('/').first }
        level = /^2\d{2,}$/.match?(code.to_s.strip) ? :info : :error

        track_request(level, message, METRIC, call_location:, tags: format_tags(tags), **tags)
      end
    end

    # Monitor to be used with Uploader
    class Uploader < Monitor
      # StatsD metric
      METRIC = 'module.claims_evidence_api.uploader'

      # track evidence upload started
      #
      # @param context [Mixed] key-value pairs to be included in tracking
      def track_upload_begun(**context)
        message = format_message('upload begun')
        tags = format_tags({ action: 'begun' })

        track_request(:info, message, METRIC, call_location:, tags:, **context)
      end

      # track evidence upload attempted
      #
      # @param context [Mixed] key-value pairs to be included in tracking
      def track_upload_attempt(**context)
        message = format_message('upload attempt')
        tags = format_tags({ action: 'attempt' })

        track_request(:info, message, METRIC, call_location:, tags:, **context)
      end

      # track evidence upload completed successfully
      #
      # @param context [Mixed] key-value pairs to be included in tracking
      def track_upload_success(**context)
        message = format_message('upload success')
        tags = format_tags({ action: 'success' })

        track_request(:info, message, METRIC, call_location:, tags:, **context)
      end

      # track evidence upload failure/error
      #
      # @param error_message [String] the error message
      # @param context [Mixed] key-value pairs to be included in tracking
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
