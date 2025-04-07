# frozen_string_literal: true

require 'logging/monitor'
require 'kafka/concerns/topic'

module Kafka
  # This Monitor class is responsible for tracking and logging various events related to the Kafka service.
  # It inherits from the ZeroSilentFailures::Monitor class and provides methods to track the
  # success and failure of submissions.
  class Monitor < Logging::Monitor
    include Kafka::Topic
    # metric prefix
    STATSD_KEY_PREFIX = 'api.kafka_service'

    def initialize
      super('kafka-service')
    end

    # Track submission successful
    # @see Kafka::EventBusSubmissionJob
    #
    # @param topic [String] The Kafka topic to which the message will be sent
    # @param payload [Hash] The message payload to be sent to the Kafka topic
    def track_submission_success(topic, payload)
      payload = redact_icn(payload)

      additional_context = { topic:, payload: }
      track_request(
        'info',
        "Kafka::EventBusSubmissionJob submission succeeded for topic #{topic}",
        "#{STATSD_KEY_PREFIX}.submission.success",
        call_location: caller_locations.first,
        **additional_context
      )
    end

    # Track submission request failure
    # @see Kafka::EventBusSubmissionJob
    #
    # @param topic [String] The Kafka topic to which the message will be sent
    # @param payload [Hash] The message payload to be sent to the Kafka topic
    # @param e [Error] the error which occurred
    def track_submission_failure(topic, payload, e)
      payload = redact_icn(payload)

      additional_context = {
        topic:,
        payload:,
        errors: e.try(:errors) || e&.message
      }
      track_request(
        'error',
        "Kafka::EventBusSubmissionJob submission failed for topic #{topic}",
        "#{STATSD_KEY_PREFIX}.submission.failure",
        call_location: caller_locations.first,
        **additional_context
      )
    end

    ##
    # log Sidkiq job exhaustion, complete failure after all retries
    # @see Kafka::EventBusSubmissionJob
    #
    # @param msg [Hash] sidekiq exhaustion response
    # @param topic [String] The Kafka topic to which the message will be sent
    # @param payload [Hash] The message payload to be sent to the Kafka topic
    #
    def track_submission_exhaustion(msg, topic, payload)
      payload = redact_icn(payload)

      additional_context = {
        topic:,
        payload:,
        message: msg
      }
      call_location = caller_locations.first

      track_request('error', "Kafka::EventBusSubmissionJob for #{topic} exhausted!",
                    "#{STATSD_KEY_PREFIX}.exhausted", call_location:, **additional_context)
    end

    private

    def redact_icn(hash)
      return hash unless hash.is_a?(Hash)

      stack = [hash]

      while (current = stack.pop)
        current.each do |key, value|
          if key.upcase == 'ICN'
            current[key] = '[REDACTED]'
          elsif value.is_a?(Hash)
            stack.push(value)
          elsif value.is_a?(Array)
            value.each { |item| stack.push(item) if item.is_a?(Hash) }
          end
        end
      end

      hash
    end
  end
end
