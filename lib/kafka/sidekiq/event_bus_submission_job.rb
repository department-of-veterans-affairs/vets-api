# frozen_string_literal: true

require 'kafka/avro_producer'
require 'kafka/monitor'

module Kafka
  class EventBusSubmissionJob
    include Sidekiq::Job
    sidekiq_options retry: 3, queue: 'low'

    # retry exhaustion
    sidekiq_retries_exhausted do |msg|
      monitor = Kafka::Monitor.new
      topic = msg['args'].first
      payload = msg['args'].second

      monitor.track_submission_exhaustion(msg, topic, payload)
    end

    # Performs the job of producing a message to a Kafka topic
    #
    # @param topic [String] The Kafka topic to which the message will be sent
    # @param payload [Hash] The message payload to be sent to the Kafka topic
    def perform(topic, payload)
      @monitor = Kafka::Monitor.new

      Kafka::AvroProducer.new.produce(topic, payload)
      @monitor.track_submission_success(topic, payload)
    rescue => e
      @monitor.track_submission_failure(topic, payload, e)
      raise e
    end
  end
end
