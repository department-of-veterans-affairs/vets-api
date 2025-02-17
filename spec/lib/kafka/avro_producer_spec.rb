# frozen_string_literal: true

require 'rails_helper'
require 'kafka/avro_producer'

describe Kafka::AvroProducer do
  let(:avro_mock) { instance_double(AvroTurf::Messaging) }
  let(:avro_producer) { described_class.new(avro: avro_mock) }

  before do
    # Mock AvroTurf::Messaging.new to return the avro_mock object
    allow(avro_producer).to receive(:avro).and_return(avro_mock)
    # Stub the encode method on the avro_mock object to return the payload as is
    allow(avro_mock).to receive(:encode) do |payload, _options|
      payload
    end
  end

  context 'producing a message successfuly' do
    # KAFKA_PRODUCER uses the buffered client for tests https://karafka.io/docs/WaterDrop-Testing/#buffered-client
    after do
      # reset the client after each test
      avro_producer.producer.client.reset
    end

    it 'produces a message to the specified topic' do
      avro_producer.produce('topic-1', { key: 'value1' }.to_json)
      avro_producer.produce('topic-1', { key: 'value2' }.to_json)
      avro_producer.produce('topic-2', { key: 'value1' }.to_json)

      expect(avro_producer.producer.client.messages.length).to eq(3)
      topic_1_messages = avro_producer.producer.client.messages_for('topic-1')
      expect(topic_1_messages.length).to eq(2)
      expect(topic_1_messages[0][:payload]).to eq('{"key":"value1"}')
    end

    it 'works with Avro encoded payloads' do
      avro_turf = AvroTurf.new(schemas_path: 'spec/fixtures/avro_schemas')
      # Use test encoding for AvroTurf
      allow(avro_mock).to receive(:encode) do |payload, _options|
        avro_turf.encode(payload, schema_name: 'test', validate: true)
      end
      avro_producer.produce('topic-1', { 'data' => { 'key' => 'value1' } })
      avro_producer.produce('topic-1', { 'data' => { 'key' => 'value2' } })

      avro_msg = avro_producer.producer.client.messages_for('topic-1').first[:payload]
      decoded_avro_msg = avro_turf.decode(avro_msg, schema_name: 'test')
      expect(decoded_avro_msg).to eq({ 'data' => { 'key' => 'value1' } })
    end
  end

  context 'when an error occurs' do
    it 'triggers MessageInvalidError if no valid topic is provided' do
      expect(Rails.logger).to receive(:error).with(/Message is invalid/)

      # Send an invalid message to trigger an error (no topic provided)
      expect do
        avro_producer.produce(nil, { key: 'value1' }.to_json)
      end.to raise_error(WaterDrop::Errors::MessageInvalidError,
                         { topic: 'does not match the topic allowed format' }.to_s)
    end

    it 'triggers MessageInvalidError if no valid payload is provided' do
      expect(Rails.logger).to receive(:error).with(/Message is invalid/)

      # Payloads larger than 1Mb are not allowed
      large_payload = 'a' * ((1 * 1024 * 1024) + 1) # 1MB + 1 byte

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
        .with(topic: 'topic-1', payload: { key: 'value1' }.to_json)
        .and_raise(StandardError)

      # Trigger the error and handle it
      expect do
        avro_producer.produce('topic-1', { key: 'value1' }.to_json)
      end.to raise_error(StandardError)
    end

    it 'logs a message when a ProducerError occurs' do
      expect(Rails.logger).to receive(:error).with(/Producer error/)
      # Simulate an error occurring in the producer
      allow(avro_producer.producer).to receive(:produce_sync)
        .with(topic: 'topic-1', payload: { key: 'value1' }.to_json)
        .and_raise(WaterDrop::Errors::ProduceError)

      # Trigger the error and handle it
      expect do
        avro_producer.produce('topic-1', { key: 'value1' }.to_json)
      end.to raise_error(WaterDrop::Errors::ProduceError)
    end

    it 'logs a message when a SchemaValidationError occurs' do
      # Use test encoding for AvroTurf to trigger a schema validation error
      allow(avro_mock).to receive(:encode) do |payload, _options|
        avro_turf = AvroTurf.new(schemas_path: 'spec/fixtures/avro_schemas')
        avro_turf.encode(payload, schema_name: 'test', validate: true)
      end
      expect(Rails.logger).to receive(:error).with(/Schema validation error/)

      # Trigger the error using an invalid schema
      expect do
        avro_producer.produce('topic-1', { key: 'value1' })
      end.to raise_error(Avro::SchemaValidator::ValidationError)
    end
  end
end
