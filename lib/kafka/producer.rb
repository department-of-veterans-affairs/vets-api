require 'avro_turf/messaging'

module Kafka
  module Producer
    def self.avro
      @avro ||= AvroTurf::Messaging.new(registry_url: Settings.kafka_producer.schema_registry_url)
    end

    def self.producer
      @producer ||= KAFKA_PRODUCER
    end

    def self.produce(topic, payload, schema_version: 1)
      encoded_payload = avro.encode(
        payload,
        subject: topic,
        version: schema_version,
        validate: true
      )
      producer.produce_sync(topic: topic, payload: encoded_payload)
    rescue => e
      # https://karafka.io/docs/WaterDrop-Error-Handling/
      # Errors are rescued and re-raised to demonstrate the types of errors that can occur
      case e
      when Avro::SchemaValidator::ValidationError
        Rails.logger.error "Schema validation error: #{e}"
        raise e
      when WaterDrop::Errors::MessageInvalidError
        # This error is raised when the message is invalid and before attempting to send it to Kafka
        Rails.logger.error "Message is invalid: #{e}"
        raise e
      when WaterDrop::Errors::ProduceError
        # This error likely means that the message was not delivered to Kafka.
        Rails.logger.error 'Producer error. See the logs for more information. This dispatch will not reach Kafka'
        raise e
      else
        # Any other errors. This should not happen and indicates trouble.
        Rails.logger.error "An unexpected error occurred while producing a message to #{topic}. Please check the logs for more information. This dispatch will not reach Kafka"
        raise e
      end
    end
  end
end
