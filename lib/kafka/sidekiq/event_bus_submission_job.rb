# frozen_string_literal: true

require 'kafka/avro_producer'
require 'kafka/monitor'
require 'kafka/concerns/topic'

module Kafka
  class EventBusSubmissionJob
    include Sidekiq::Job
    include Kafka::Topic

    sidekiq_options retry: 3, queue: 'low'

    # retry exhaustion
    sidekiq_retries_exhausted do |msg|
      monitor = Kafka::Monitor.new
      payload = msg['args'].first
      use_test_topic = msg['args'].second
      topic = get_topic(use_test_topic:)

      monitor.track_submission_exhaustion(msg, topic, payload)
    end

    # Performs the job of producing a message to a Kafka topic
    #
    # @param topic [String] The Kafka topic to which the message will be sent
    # @param payload [Hash] The message payload to be sent to the Kafka topic
    def perform(payload, use_test_topic: false)
      @monitor = Kafka::Monitor.new
      topic = get_topic(use_test_topic:)

      Kafka::AvroProducer.new.produce(payload, topic)
      @monitor.track_submission_success(topic, payload)
    rescue => e
      @monitor.track_submission_failure(topic, payload, e)
      raise e
    end
  end
end
