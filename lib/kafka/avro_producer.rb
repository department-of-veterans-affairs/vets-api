# frozen_string_literal: true

require 'avro'
require 'kafka/producer_manager'
require 'kafka/schema_registry/service'
require 'logger'
require 'kafka/models/form_trace'

module Kafka
  class AvroProducer
    attr_reader :producer, :registry

    def initialize(producer: nil)
      @producer = producer || Kafka::ProducerManager.instance.producer
      @registry = SchemaRegistry::Service.new
      @schema_id = nil
    end

    def produce(topic, payload, schema_version: 'latest')
      schema = get_schema(topic, schema_version)
      encoded_payload = encode_payload(schema, payload)
      producer.produce_sync(topic:, payload: encoded_payload)
    rescue => e
      # https://karafka.io/docs/WaterDrop-Error-Handling/
      # Errors are rescued and re-raised to demonstrate the types of errors that can occur
      log_error(e, topic)
      raise
    end

    private

    def get_schema(topic, schema_version)
      response = @registry.subject_version(topic, schema_version)
      schema = response['schema']
      @schema_id = response['id']
      Avro::Schema.parse(schema)
    end

    def encode_payload(schema, payload)
      validate_payload!(schema, payload)

      datum_writer = Avro::IO::DatumWriter.new(schema)
      buffer = StringIO.new
      encoder = Avro::IO::BinaryEncoder.new(buffer)
      datum_writer.write(payload, encoder)
      avro_payload = buffer.string

      # Add magic byte and schema ID to the payload
      magic_byte = [0].pack('C')
      schema_id_bytes = [@schema_id].pack('N') # should be schema id
      magic_byte + schema_id_bytes + avro_payload
    end

    def validate_payload!(schema, payload)
      Avro::SchemaValidator.validate!(schema, payload)
    end

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
