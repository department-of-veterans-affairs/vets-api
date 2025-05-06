# frozen_string_literal: true

require 'rails_helper'
require 'kafka/avro_producer'
require 'kafka/oauth_token_refresher'

describe Kafka::AvroProducer do
  let(:avro_producer) { described_class.new }
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
  let(:topic_payload_value) do
    "\x00\x00\x00\x00\x05\x00\n12345\x00\x02\x12ICN123456" \
    "\x12VASI98765\x00\x00\x00\x00\x10received(2024-03-04T12:00:00Z\x00".b
  end
  let(:topic) { 'submission_trace_form_status_change_test' }

  after do
    avro_producer.producer.client.reset
  end

  describe 'validate payload' do
    # valid data format
    it 'validates the payload against the schema' do
      VCR.use_cassette('kafka/topics') do
        avro_producer.produce(topic, valid_payload)
        expect(avro_producer.producer.client.messages.length).to eq(1)
        topic_3_messages = avro_producer.producer.client.messages_for('submission_trace_form_status_change_test')
        expect(topic_3_messages.length).to eq(1)
        expect(topic_3_messages[0][:payload]).to be_a(String)
        expect(topic_3_messages[0][:payload]).to eq(topic_payload_value)
      end
    end

    # currentId
    it 'raises a validation error when currentId is missing' do
      invalid_payload = valid_payload.dup
      invalid_payload.delete('currentId')

      VCR.use_cassette('kafka/topics') do
        expect do
          avro_producer.produce(topic, invalid_payload)
        end.to raise_error(Avro::SchemaValidator::ValidationError)
      end
    end

    # currentId
    it 'raises a validation error when currentId is not a string' do
      invalid_payload = valid_payload.dup
      invalid_payload['currentId'] = 12_345

      VCR.use_cassette('kafka/topics') do
        expect do
          avro_producer.produce(topic, invalid_payload)
        end.to raise_error(Avro::SchemaValidator::ValidationError)
      end
    end

    # vasiId
    it 'raises a validation error when vasiId is missing' do
      invalid_payload = valid_payload.dup
      invalid_payload.delete('vasiId')

      VCR.use_cassette('kafka/topics') do
        expect do
          avro_producer.produce(topic, invalid_payload)
        end.to raise_error(Avro::SchemaValidator::ValidationError)
      end
    end

    it 'raises a validation error when vasiId is not a string' do
      invalid_payload = valid_payload.dup
      invalid_payload['vasiId'] = 12_345

      VCR.use_cassette('kafka/topics') do
        expect do
          avro_producer.produce(topic, invalid_payload)
        end.to raise_error(Avro::SchemaValidator::ValidationError)
      end
    end

    # systemName
    it 'raises a validation error when systemName is missing' do
      invalid_payload = valid_payload.dup
      invalid_payload.delete('systemName')

      VCR.use_cassette('kafka/topics') do
        expect do
          avro_producer.produce(topic, invalid_payload)
        end.to raise_error(Avro::SchemaValidator::ValidationError)
      end
    end

    it 'raises a validation error when systemName has an invalid value' do
      invalid_payload = valid_payload.dup
      invalid_payload['systemName'] = 'invalid_systemName'

      VCR.use_cassette('kafka/topics') do
        expect do
          avro_producer.produce(topic, invalid_payload)
        end.to raise_error(Avro::SchemaValidator::ValidationError)
      end
    end

    # submissionName
    it 'raises a validation error when submissionName is missing' do
      invalid_payload = valid_payload.dup
      invalid_payload.delete('submissionName')

      VCR.use_cassette('kafka/topics') do
        expect do
          avro_producer.produce(topic, invalid_payload)
        end.to raise_error(Avro::SchemaValidator::ValidationError)
      end
    end

    it 'raises a validation error when submissionName has an invalid value' do
      invalid_payload = valid_payload.dup
      invalid_payload['submissionName'] = 'invalid_submissionName'

      VCR.use_cassette('kafka/topics') do
        expect do
          avro_producer.produce(topic, invalid_payload)
        end.to raise_error(Avro::SchemaValidator::ValidationError)
      end
    end

    # state
    it 'raises a validation error when state is missing' do
      invalid_payload = valid_payload.dup
      invalid_payload.delete('state')

      VCR.use_cassette('kafka/topics') do
        expect do
          avro_producer.produce(topic, invalid_payload)
        end.to raise_error(Avro::SchemaValidator::ValidationError)
      end
    end

    # timestamp
    it 'raises a validation error when timestamp is missing' do
      invalid_payload = valid_payload.dup
      invalid_payload.delete('timestamp')

      VCR.use_cassette('kafka/topics') do
        expect do
          avro_producer.produce(topic, invalid_payload)
        end.to raise_error(Avro::SchemaValidator::ValidationError)
      end
    end

    it 'raises a validation error when timestamp is not a string' do
      invalid_payload = valid_payload.dup
      invalid_payload['timestamp'] = 12_345

      VCR.use_cassette('kafka/topics') do
        expect do
          avro_producer.produce(topic, invalid_payload)
        end.to raise_error(Avro::SchemaValidator::ValidationError)
      end
    end

    # additionalIds
    it 'raises no validation error when additionalIds is an array of strings' do
      valid_payload_with_add_ids = valid_payload.dup
      valid_payload_with_add_ids['additionalIds'] = %w[1 123 abc456]

      VCR.use_cassette('kafka/topics') do
        avro_producer.produce(topic, valid_payload_with_add_ids)
        expect(avro_producer.producer.client.messages.length).to eq(1)
      end
    end

    it 'raises a validation error when additionalIds is not an array of strings' do
      invalid_payload = valid_payload.dup
      invalid_payload['additionalIds'] = 'non_array_string'

      VCR.use_cassette('kafka/topics') do
        expect do
          avro_producer.produce(topic, invalid_payload)
        end.to raise_error(Avro::SchemaValidator::ValidationError)
      end
    end

    # invalid data format
    it 'raises a validation error for invalid payload' do
      VCR.use_cassette('kafka/topics') do
        expect do
          avro_producer.produce(topic, invalid_payload_format)
        end.to raise_error(Avro::SchemaValidator::ValidationError)
      end
    end

    it 'raises a validation error for missing payload' do
      VCR.use_cassette('kafka/topics') do
        expect do
          avro_producer.produce(topic, nil)
        end.to raise_error(Avro::SchemaValidator::ValidationError)
      end
    end
  end
end
