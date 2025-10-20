# frozen_string_literal: true

require 'logging/monitor'

module ClaimsEvidenceApi
  # @see Logging::Monitor
  class Monitor < ::Logging::Monitor
    # create a claims evidence monitor
    #
    # @param allowlist [Array<String>] list of allowed params
    def initialize(allowlist = [])
      super('claims-evidence-api', allowlist:)
    end

    # utility function, @see Rails.logger
    #
    # @param msg [Mixed] the message to be logged
    #
    # @return [String] the formatted message, preceded with the monitor class name
    def format_message(msg)
      format('%<class>s: %<msg>s', { class: self.class.name, msg: msg.to_s })
    end

    # utility function to format metric tags for DataDog
    #
    # @param tag_hash [Hash] key-value pairs for metric tags
    #
    # @return [Array<String>] an array of string; eg. ["key:value" ...]
    def format_tags(tag_hash)
      tag_hash.map { |key, value| "#{key}:#{value}" }
    end

    # Monitor to be used within ActiveRecord models
    class Record < Monitor
      # StatsD metric
      METRIC = 'module.claims_evidence_api.record'
      # allowed logging params
      ALLOWLIST = %w[
        action
        class
        doctype
        file_uuid
        form_id
        id
        persistent_attachment_id
        saved_claim_id
        status
        submission_id
      ].freeze

      attr_reader :record

      def initialize(record)
        super(ALLOWLIST)
        @record = record
      end

      # track the action performed on a record
      #
      # @param action [String|Symbol] eg. create, update, delete
      # @param attributes [Mixed] named key-value pairs of record attributes
      def track_event(action, **attributes)
        call_location = caller_locations.first
        message = format_message("#{record.class} #{action}")
        tags = format_tags({
                             class: record.class.to_s.downcase.gsub(/:+/, '_'),
                             form_id: attributes[:form_id],
                             doctype: attributes[:doctype],
                             action:
                           })

        track_request(:info, message, METRIC, call_location:, tags:, **attributes)
      end
    end

    # Monitor to be used within Service classes
    class Service < Monitor
      # StatsD metric
      METRIC = 'module.claims_evidence_api.service.request'
      # allowed logging params
      ALLOWLIST = %w[
        code
        endpoint
        method
        reason
      ].freeze

      def initialize
        super(ALLOWLIST)
      end

      # track the api request performed and the response/error
      # @see Common::Client::Base#perform
      # @see Common::Client::Errors::ClientError
      #
      # @param method [String|Symbol] eg. get, post, put
      # @param endpoint [String] the requested service endpoint
      # @param code [Integer|String] the response code
      # @param reason [String] the response `reason_phrase`
      # @param call_location [Logging::CallLocation|Thread::Backtrace::Location] calling point to be logged
      def track_api_request(method, endpoint, code, reason, call_location: nil)
        call_location ||= caller_locations.first

        message = format_message("#{code} #{reason}")
        tags = { method:, code:, endpoint: }

        level = /^2\d\d$/.match?(code.to_s.strip) ? :info : :error

        track_request(level, message, METRIC, call_location:, reason:, tags: format_tags(tags), **tags)
      end
    end

    # Monitor to be used with Uploader
    class Uploader < Monitor
      # StatsD metric
      METRIC = 'module.claims_evidence_api.uploader'
      # allowed logging params
      ALLOWLIST = %w[
        action
        doctype
        error
        form_id
        persistent_attachment_id
        saved_claim_id
        stamp_set
      ].freeze

      def initialize
        super(ALLOWLIST)
      end

      # track evidence upload started
      #
      # @param context [Mixed] key-value pairs to be included in tracking
      def track_upload_begun(**context)
        track_upload(:begun, **context)
      end

      # track evidence upload attempted
      #
      # @param context [Mixed] key-value pairs to be included in tracking
      def track_upload_attempt(**context)
        track_upload(:attempt, **context)
      end

      # track evidence upload completed successfully
      #
      # @param context [Mixed] key-value pairs to be included in tracking
      def track_upload_success(**context)
        track_upload(:success, **context)
      end

      # track evidence upload failure/error
      #
      # @param error_message [String] the error message
      # @param context [Mixed] key-value pairs to be included in tracking
      def track_upload_failure(error_message, **context)
        track_upload(:failure, "ERROR #{error_message}", **context)
      end

      private

      # track evidence upload
      #
      # @param error [String] the error message to accompany the log
      # @param context [Mixed] key-value pairs to be included in tracking
      def track_upload(stage, error = nil, **context)
        msg = "upload #{stage}"
        msg += " - #{error}" if error

        context[:action] = stage.to_s
        tags = context.slice(:action, :form_id, :doctype)

        call_location = caller_locations.second
        level = stage == :failure ? :error : :info
        msg = format_message(msg)
        tags = format_tags(tags)

        track_request(level, msg, METRIC, call_location:, tags:, error:, **context)
      end
    end
  end
end
