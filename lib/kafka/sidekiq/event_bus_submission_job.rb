# frozen_string_literal: true

require 'kafka/avro_producer'
require 'kafka/monitor'
require 'kafka/concerns/kafka'

module Kafka
  class EventBusSubmissionJob
    include Sidekiq::Job

    sidekiq_options retry: 3, queue: 'low'

    # retry exhaustion
    sidekiq_retries_exhausted do |msg|
      monitor = Kafka::Monitor.new
      payload = msg['args'].first
      use_test_topic = msg['args'].second
      topic = get_topic(use_test_topic:)
      redacted_payload = Kafka.redact_icn(payload)

      monitor.track_submission_exhaustion(msg, topic, redacted_payload)
    end

    # Performs the job of producing a message to a Kafka topic
    #
    # @param topic [String] The Kafka topic to which the message will be sent
    # @param payload [Hash] The message payload to be sent to the Kafka topic
    def perform(payload, use_test_topic = false) # rubocop:disable Style/OptionalBooleanParameter
      @monitor = Kafka::Monitor.new
      topic = Kafka.get_topic(use_test_topic:)
      Kafka::AvroProducer.new.produce(topic, payload)
      redacted_payload = Kafka.redact_icn(payload)
      @monitor.track_submission_success(topic, redacted_payload)
    rescue => e
      redacted_payload = Kafka.redact_icn(payload)
      @monitor.track_submission_failure(topic, redacted_payload, e)
      raise e
    end
  end
end
