# frozen_string_literal: true

require 'rails_helper'
require 'kafka/producer'

fdescribe Kafka::Producer do
  context 'when the producer is created' do
    it 'returns a WaterDrop producer' do
      expect(described_class.producer).to be_a(WaterDrop::Producer)
    end

    it 'returns the same producer instance on multiple invocations' do
      producer = described_class.producer
      expect(described_class.producer.id).to eq(producer.id)
    end
  end

  context 'producing a message successfuly' do
    # Using the buffered client for tests - https://karafka.io/docs/WaterDrop-Testing/#buffered-client
    it 'produces a message to the specified topic' do
      described_class.produce('topic-1', { key: 'value1' })
      described_class.produce('topic-1', { key: 'value2' })
      described_class.produce('topic-2', { key: 'value1' })

      expect(described_class.producer.client.messages.length).to eq(3)
      topic_1_messages = described_class.producer.client.messages_for('topic-1')
      expect(topic_1_messages.length).to eq(2)
      expect(topic_1_messages[0][:payload]).to eq('{"key":"value1"}')
    end
  end

  context 'when an error occurs' do
    it 'triggers MessageInvalidError if no valid topic is provided' do
      expect(Rails.logger).to receive(:error).with(/Message is invalid/)

      # Send an invalid message to trigger an error (no topic provided)
      expect do
        described_class.produce(nil, { key: 'value1' })
      end.to raise_error(WaterDrop::Errors::MessageInvalidError,
                         { topic: 'does not match the topic allowed format' }.to_s)
    end

    it 'triggers MessageInvalidError if no valid payload is provided' do
      expect(Rails.logger).to receive(:error).with(/Message is invalid/)

      # Payloads larger than 1Mb are not allowed
      large_payload = 'a' * ((1 * 1024 * 1024) + 1) # 1MB + 1 byte

      # Send an invalid message to trigger an error (no payload provided)
      expect do
        described_class.produce('topic-1', large_payload)
      end.to raise_error(WaterDrop::Errors::MessageInvalidError,
                         { payload: 'is more than `max_payload_size` config value' }.to_s)
    end

    it 'logs a message when an unexpected error occurs' do
      expect(Rails.logger).to receive(:error).with(/An unexpected error occurred/)
      # Simulate an error occurring in the producer
      allow(described_class.producer).to receive(:produce_sync)
        .with(topic: 'topic-1', payload: { key: 'value1' }.to_json)
        .and_raise(StandardError)

      # Trigger the error and handle it
      expect do
        described_class.produce('topic-1', { key: 'value1' })
      end.to raise_error(StandardError)
    end

    it 'logs a message when a ProducerError occurs' do
      expect(Rails.logger).to receive(:error).with(/Producer error/)
      # Simulate an error occurring in the producer
      allow(described_class.producer).to receive(:produce_sync)
        .with(topic: 'topic-1', payload: { key: 'value1' }.to_json)
        .and_raise(WaterDrop::Errors::ProduceError)

      # Trigger the error and handle it
      expect do
        described_class.produce('topic-1', { key: 'value1' })
      end.to raise_error(WaterDrop::Errors::ProduceError)
    end
  end
end
