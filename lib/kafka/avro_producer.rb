# frozen_string_literal: true

require 'avro'
require 'kafka/producer_manager'
require 'kafka/schema_registry/service'
require 'logger'

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
      if Flipper.enabled?(:kafka_producer_fetch_schema_dynamically)
        response = @registry.subject_version(topic, schema_version)
        schema = response['schema']
        @schema_id = response['id']
      else
        schema_path = Rails.root.join('lib', 'kafka', 'schemas', "#{topic}-value-#{schema_version}.avsc")
        schema = File.read(schema_path)
      end

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
      # NOTE: Use fetched schema id from schema registry but if not found,
      # ID = 5 is the Event Bus schema ID for test schema.replace this with the actual schema ID when running locally
      @schema_id ||= 5
      # @schema_id ||= 1
      # ^ set to [1] locally until fixed
      schema_id_bytes = [@schema_id].pack('N') # should be schema id
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
