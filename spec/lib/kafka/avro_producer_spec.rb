# frozen_string_literal: true

require 'rails_helper'
require 'kafka/avro_producer'

describe Kafka::AvroProducer do
  let(:avro_producer) { described_class.new }
  let(:schema_path) { Rails.root.join('lib', 'kafka', 'schemas', 'test-value-1.avsc') }
  let(:schema) { Avro::Schema.parse(File.read(schema_path)) }
  let(:valid_payload) { { 'data' => { 'key' => 'value' } } }
  let(:invalid_payload) { { 'invalid_key' => 'value' } }

  before do
    allow(avro_producer).to receive(:get_schema).and_return(schema)
  end

  context 'producing a message successfully' do
    after do
      # reset the client after each test
      avro_producer.producer.client.reset
    end

    it 'produces a message to the specified topic' do
      avro_producer.produce('topic-1', valid_payload)
      avro_producer.produce('topic-1', valid_payload)
      avro_producer.produce('topic-2', valid_payload)

      expect(avro_producer.producer.client.messages.length).to eq(3)
      topic_1_messages = avro_producer.producer.client.messages_for('topic-1')
      expect(topic_1_messages.length).to eq(2)
      expect(topic_1_messages[0][:payload]).to be_a(String)
    end
  end

  context 'when an error occurs' do
    it 'triggers MessageInvalidError if no valid topic is provided' do
      expect(Rails.logger).to receive(:error).with(/Message is invalid/)

      # Send an invalid message to trigger an error (no topic provided)
      expect do
        avro_producer.produce(nil, valid_payload)
      end.to raise_error(WaterDrop::Errors::MessageInvalidError,
                         { topic: 'does not match the topic allowed format' }.to_s)
    end

    it 'triggers MessageInvalidError if no valid payload is provided' do
      expect(Rails.logger).to receive(:error).with(/Message is invalid/)

      # Payloads larger than 1Mb are not allowed
      large_payload = 'a' * ((1 * 1024 * 1024) + 1) # 1MB + 1 byte

      allow(avro_producer).to receive(:encode_payload).and_return(large_payload)

      # Send an invalid message to trigger an error (no payload provided)
      expect do
        avro_producer.produce('topic-1', large_payload)
      end.to raise_error(WaterDrop::Errors::MessageInvalidError,
                         { payload: 'is more than `max_payload_size` config value' }.to_s)
    end

    it 'logs a message when an unexpected error occurs' do
      expect(Rails.logger).to receive(:error).with(/An unexpected error occurred/)
      # Simulate an error occurring in the producer
      allow(avro_producer.producer).to receive(:produce_sync)
        .and_raise(StandardError)

      # Trigger the error and handle it
      expect do
        avro_producer.produce('topic-1', valid_payload)
      end.to raise_error(StandardError)
    end

    it 'logs a message when a ProducerError occurs' do
      expect(Rails.logger).to receive(:error).with(/Producer error/)
      # Simulate an error occurring in the producer
      allow(avro_producer.producer).to receive(:produce_sync)
        .and_raise(WaterDrop::Errors::ProduceError)

      # Trigger the error and handle it
      expect do
        avro_producer.produce('topic-1', valid_payload)
      end.to raise_error(WaterDrop::Errors::ProduceError)
    end

    it 'logs a message when a SchemaValidationError occurs' do
      expect(Rails.logger).to receive(:error).with(/Schema validation error/)
      # Simulate a schema validation error
      # allow(Avro::SchemaValidator).to receive(:validate!).and_raise(Avro::SchemaValidator::ValidationError)

      # Trigger the error using an invalid schema
      expect do
        avro_producer.produce('topic-1', invalid_payload)
      end.to raise_error(Avro::SchemaValidator::ValidationError)
    end
  end

  describe '#encode_payload' do
    it 'encodes the payload using the specified schema' do
      encoder = Avro::IO::BinaryEncoder.new(StringIO.new)
      datum_writer = Avro::IO::DatumWriter.new(schema)

      expect(Avro::IO::DatumWriter).to receive(:new).with(schema).and_return(datum_writer)
      expect(Avro::IO::BinaryEncoder).to receive(:new).with(kind_of(StringIO)).and_return(encoder)
      expect(datum_writer).to receive(:write).with(valid_payload, encoder)

      encoded_payload = avro_producer.send(:encode_payload, schema, valid_payload)
      expect(encoded_payload).to be_a(String)
    end
  end

  describe '#validate_payload!' do
    it 'validates the payload against the schema' do
      expect(Avro::SchemaValidator).to receive(:validate!).with(schema, valid_payload)
      avro_producer.send(:validate_payload!, schema, valid_payload)
    end

    it 'raises a validation error for invalid payload' do
      expect do
        avro_producer.send(:validate_payload!, schema, invalid_payload)
      end.to raise_error(Avro::SchemaValidator::ValidationError)
    end
  end
end
