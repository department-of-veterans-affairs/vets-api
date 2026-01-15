# frozen_string_literal: true

require 'logging/monitor'

module Kafka
  # This Monitor class is responsible for tracking and logging various events related to the Kafka service.
  # It inherits from the ZeroSilentFailures::Monitor class and provides methods to track the
  # success and failure of submissions.
  class Monitor < Logging::Monitor
    # metric prefix
    STATSD_KEY_PREFIX = 'api.kafka_service'

    def initialize
      # the allowlist includes 'tags' so that tags are not filtered out in logs.
      super('kafka-service', allowlist: ['tags'])
    end

    # Track submission successful
    # @see Kafka::EventBusSubmissionJob
    #
    # @param topic [String] The Kafka topic to which the message will be sent
    # @param payload [Hash] The message payload to be sent to the Kafka topic
    def track_submission_success(topic, payload)
      additional_context = { topic:, kafka_payload: payload, tags: add_tags(payload) }
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
      additional_context = {
        topic:,
        kafka_payload: payload,
        errors: e.try(:errors) || e&.message,
        tags: add_tags(payload)
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
      additional_context = {
        topic:,
        kafka_payload: payload,
        message: msg,
        tags: add_tags(payload)
      }
      call_location = caller_locations.first

      track_request('error', "Kafka::EventBusSubmissionJob for #{topic} exhausted!",
                    "#{STATSD_KEY_PREFIX}.exhausted", call_location:, **additional_context)
    end

    private

    def add_tags(payload)
      return [] unless payload.is_a?(Hash) && payload.key?('submissionName') && payload.key?('state')

      ["form:#{payload['submissionName']}", "state:#{payload['state']}"]
    end
  end
end
