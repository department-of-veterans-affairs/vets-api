# frozen_string_literal: true

require 'rails_helper'
require 'kafka/avro_producer'
require 'kafka/oauth_token_refresher'

describe Kafka::AvroProducer do
  let(:avro_producer) { described_class.new }
  let(:schema_path) { Rails.root.join('lib', 'kafka', 'schemas', 'submission_trace_schema_dev-value-1.avsc') }
  let(:schema_file) { File.read(schema_path) }
  let(:schema) { Avro::Schema.parse(File.read(schema_path)) }
  let(:valid_payload) do
    {
      'priorId' => nil,
      'currentId' => '12345',
      'nextId' => nil,
      'icn' => 'ICN123456',
      'vasiId' => 'VASI98765',
      'systemName' => 'Lighthouse',
      'submissionName' => 'F1010EZ',
      'state' => 'received',
      'timestamp' => '2024-03-04T12:00:00Z',
      'additionalIds' => nil
    }
  end
  let(:invalid_payload_format) { 'invalid' }

  context 'producing a message successfully' do
    let(:topic3_payload_value) { "\x00\x00\x00\x00\x05\x00\n12345\x00\x02\x12ICN123456\x12VASI98765\x00\x00\x00\x00\x00\x00(2024-03-04T12:00:00Z\x00" }

    before do
      Kafka::ProducerManager.instance.send(:setup_producer)
    end

    after do
      # reset the client after each test
      avro_producer.producer.client.reset
    end

    context 'with dynamic schema registry retrieval' do

      context 'of an existing schema' do
        it 'produces a message to the specified topic' do
          VCR.use_cassette('kafka/topics') do
            avro_producer.produce('topic-3', valid_payload)
            avro_producer.produce('topic-4', valid_payload)
            expect(avro_producer.producer.client.messages.length).to eq(2)        
            topic_3_messages = avro_producer.producer.client.messages_for('topic-3')
            expect(topic_3_messages.length).to eq(1)
            expect(topic_3_messages[0][:payload]).to be_a(String)
            expect(topic_3_messages[0][:payload]).to eq(topic3_payload_value)
          end
        end
      end

      context 'of an non-existing schema' do
        it 'raises appropriate error' do
          VCR.use_cassette('kafka/topics404') do
            expect do
              avro_producer.produce('topic-999', valid_payload)
            end.to raise_error(Faraday::ResourceNotFound)
          end
        end
      end
    end

    context 'with hardcoded schema registry retrieval' do
      before do
        allow(Flipper).to receive(:enabled?).with(:kafka_producer_fetch_schema_dynamically).and_return(false)
        allow(File).to receive(:read).and_return(schema_file)
      end

      it 'produces a message to the specified topic' do
        avro_producer.produce('submission_trace_schema_dev', valid_payload)
        expect(avro_producer.producer.client.messages.length).to eq(1)
        topic_3_messages = avro_producer.producer.client.messages_for('submission_trace_schema_dev')
        expect(topic_3_messages.length).to eq(1)
        expect(topic_3_messages[0][:payload]).to be_a(String)
        expect(topic_3_messages[0][:payload]).to eq(topic3_payload_value)
      end
    end
  end

  describe '#validate_payload!' do
    # valid data format
    it 'validates the payload against the schema' do
      expect(Avro::SchemaValidator).to receive(:validate!).with(schema, valid_payload)
      avro_producer.send(:validate_payload!, schema, valid_payload)
    end

    # currentId
    it 'raises a validation error when currentId is missing' do
      invalid_payload = valid_payload.dup
      invalid_payload.delete('currentId')
      expect do
        avro_producer.send(:validate_payload!, schema, invalid_payload)
      end.to raise_error(Avro::SchemaValidator::ValidationError)
    end

    it 'raises a validation error when currentId is not a string' do
      invalid_payload = valid_payload.dup
      invalid_payload['currentId'] = 12_345
      expect do
        avro_producer.send(:validate_payload!, schema, invalid_payload)
      end.to raise_error(Avro::SchemaValidator::ValidationError)
    end

    # vasiId
    it 'raises a validation error when vasiId is missing' do
      invalid_payload = valid_payload.dup
      invalid_payload.delete('vasiId')
      expect do
        avro_producer.send(:validate_payload!, schema, invalid_payload)
      end.to raise_error(Avro::SchemaValidator::ValidationError)
    end

    it 'raises a validation error when vasiId is not a string' do
      invalid_payload = valid_payload.dup
      invalid_payload['vasiId'] = 12_345
      expect do
        avro_producer.send(:validate_payload!, schema, invalid_payload)
      end.to raise_error(Avro::SchemaValidator::ValidationError)
    end

    # systemName
    it 'raises a validation error when systemName is missing' do
      invalid_payload = valid_payload.dup
      invalid_payload.delete('systemName')
      expect do
        avro_producer.send(:validate_payload!, schema, invalid_payload)
      end.to raise_error(Avro::SchemaValidator::ValidationError)
    end

    it 'raises a validation error when systemName has an invalid value' do
      invalid_payload = valid_payload.dup
      invalid_payload['systemName'] = 'invalid_systemName'
      expect do
        avro_producer.send(:validate_payload!, schema, invalid_payload)
      end.to raise_error(Avro::SchemaValidator::ValidationError)
    end

    # submissionName
    it 'raises a validation error when submissionName is missing' do
      invalid_payload = valid_payload.dup
      invalid_payload.delete('submissionName')
      expect do
        avro_producer.send(:validate_payload!, schema, invalid_payload)
      end.to raise_error(Avro::SchemaValidator::ValidationError)
    end

    it 'raises a validation error when submissionName has an invalid value' do
      invalid_payload = valid_payload.dup
      invalid_payload['submissionName'] = 'invalid_submissionName'
      expect do
        avro_producer.send(:validate_payload!, schema, invalid_payload)
      end.to raise_error(Avro::SchemaValidator::ValidationError)
    end

    # state
    it 'raises a validation error when state is missing' do
      invalid_payload = valid_payload.dup
      invalid_payload.delete('state')
      expect do
        avro_producer.send(:validate_payload!, schema, invalid_payload)
      end.to raise_error(Avro::SchemaValidator::ValidationError)
    end

    it 'raises a validation error when state has an invalid value' do
      invalid_payload = valid_payload.dup
      invalid_payload['state'] = 'invalid_state'
      expect do
        avro_producer.send(:validate_payload!, schema, invalid_payload)
      end.to raise_error(Avro::SchemaValidator::ValidationError)
    end

    # timestamp
    it 'raises a validation error when timestamp is missing' do
      invalid_payload = valid_payload.dup
      invalid_payload.delete('timestamp')
      expect do
        avro_producer.send(:validate_payload!, schema, invalid_payload)
      end.to raise_error(Avro::SchemaValidator::ValidationError)
    end

    it 'raises a validation error when timestamp is not a string' do
      invalid_payload = valid_payload.dup
      invalid_payload['timestamp'] = 12_345
      expect do
        avro_producer.send(:validate_payload!, schema, invalid_payload)
      end.to raise_error(Avro::SchemaValidator::ValidationError)
    end

    # invalid data format
    it 'raises a validation error for invalid payload' do
      expect do
        avro_producer.send(:validate_payload!, schema, invalid_payload_format)
      end.to raise_error(Avro::SchemaValidator::ValidationError)
    end

    it 'raises a validation error for missing payload' do
      expect do
        avro_producer.send(:validate_payload!, schema, nil)
      end.to raise_error(Avro::SchemaValidator::ValidationError)
    end
  end
end
