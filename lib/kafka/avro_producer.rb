# frozen_string_literal: true

require 'avro_turf/messaging'
require 'kafka/producer_manager'

module Kafka
  class AvroProducer
    attr_reader :producer, :avro

    def initialize(producer: nil, avro: nil)
      @producer = producer || Kafka::ProducerManager.instance.producer
      @avro = avro || AvroTurf::Messaging.new(registry_url: Settings.kafka_producer.schema_registry_url)
    end

    def produce(topic, payload, schema_version: 1)
      # avro_turf.encode(payload, schema_name: 'test', validate: true)
      encoded_payload = avro.encode(
        payload,
        subject: "#{topic}-value",
        version: schema_version,
        validate: true
      )

      producer.produce_sync(topic:, payload: encoded_payload)
    rescue => e
      # https://karafka.io/docs/WaterDrop-Error-Handling/
      # Errors are rescued and re-raised to demonstrate the types of errors that can occur
      log_error(e, topic)
      raise
    end

    private

    def log_error(error, topic)
      case error
      when Avro::SchemaValidator::ValidationError
        Rails.logger.error "Schema validation error: #{error}"
      when WaterDrop::Errors::MessageInvalidError
        Rails.logger.error "Message is invalid: #{error}"
      when WaterDrop::Errors::ProduceError
        Rails.logger.error 'Producer error. See the logs for more information. ' \
                           'This dispatch will not reach Kafka'
      else
        Rails.logger.error 'An unexpected error occurred while producing a message to ' \
                           "#{topic}. Please check the logs for more information. " \
                           'This dispatch will not reach Kafka'
      end
    end
  end
end
