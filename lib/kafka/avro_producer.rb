# frozen_string_literal: true

require 'avro'
require 'kafka/producer_manager'

module Kafka
  class AvroProducer
    attr_reader :producer

    def initialize(producer: nil)
      @producer = producer || Kafka::ProducerManager.instance.producer
    end

    def produce(topic, payload, schema_version: 1)
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
      schema_path = Rails.root.join('lib', 'kafka', 'schemas', "#{topic}-value-#{schema_version}.avsc")
      Avro::Schema.parse(File.read(schema_path))
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
      # NOTE: This is a placeholder schema ID. In a real-world scenario, this should be fetched from a schema registry
      # ID = 5 is the Event Bus schema ID for test schema, replace this with the actual schema ID when running locally
      # schema_id_bytes = [5].pack('N') # should be schema id
      # ^ set to the id returned by jq locally until fixed (probably [1] or [2]?)
      schema_id_bytes = [1].pack('N') # should be schema id
      magic_byte + schema_id_bytes + avro_payload
    end

    def validate_payload!(schema, payload)
      Rails.logger.info '~~~~~~~~~~~~~~~ validate_payload schema, payload:', schema, payload


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
