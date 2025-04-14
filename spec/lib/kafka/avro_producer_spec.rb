# frozen_string_literal: true

require 'rails_helper'
require 'kafka/avro_producer'
require 'kafka/oauth_token_refresher'
require 'kafka/schema_registry/service'

describe Kafka::AvroProducer do
  let(:avro_producer) { described_class.new }
  let(:topic) { 'submission_trace_form_status_change_test' }
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
  let(:valid_test_payload) { { 'data' => { 'key' => 'value' } } }
  let(:invalid_payload) { { 'invalid_key' => 'value' } }
  let(:schema) do
    VCR.use_cassette('kafka/topics') do
      response = Kafka::SchemaRegistry::Service.new.subject_version('submission_trace_form_status_change_test',
                                                                    'latest')

      schema = response['schema']
      Avro::Schema.parse(schema)
    end
  end

  before do
    allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('test'))
    allow(Flipper).to receive(:enabled?).with(:kafka_producer).and_return(true)
    allow(Kafka::OauthTokenRefresher).to receive(:new).and_return(double(on_oauthbearer_token_refresh: 'token'))
  end

  context 'using the correct client' do
    context 'in the test environment' do
      before do
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('test'))
        Kafka::ProducerManager.instance.send(:setup_producer) # Reinitialize the producer with the mocked environment
        allow(avro_producer).to receive(:get_schema).and_return(schema)
      end

      it 'uses the Buffered client' do
        expect(avro_producer.producer.client).to be_a(WaterDrop::Clients::Buffered)
      end
    end

    context 'in other environments' do
      before do
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
        Kafka::ProducerManager.instance.send(:setup_producer) # Reinitialize the producer with the mocked environment
        allow(avro_producer).to receive(:get_schema).and_return(schema)
      end

      it 'uses the Rdkafka client' do
        expect(avro_producer.producer.client).to be_a(Rdkafka::Producer)
      end
    end
  end

  context 'producing a message successfully' do
    let(:topic1_payload_value) { "\x00\x00\x00\x00\x05\x02\x06key\nvalue\x00" }

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
            avro_producer.produce(topic, valid_payload)
            avro_producer.produce('submission_trace_mock_test', valid_test_payload)
            expect(avro_producer.producer.client.messages.length).to eq(2)
            topic_1_messages = avro_producer.producer.client.messages_for('submission_trace_form_status_change_test')
            expect(topic_1_messages.length).to eq(1)
            expect(topic_1_messages[0][:payload]).to be_a(String)
          end
        end
      end

      context 'of an non-existing schema' do
        it 'raises approriate error' do
          allow(Settings.kafka_producer).to receive(:topic_name).and_return('topic-999')

          VCR.use_cassette('kafka/topics404') do
            expect do
              avro_producer.produce('topic-999', valid_payload)
            end.to raise_error(Faraday::ResourceNotFound)
          end
        end
      end
    end
  end

  context 'when an error occurs' do
    before do
      Kafka::ProducerManager.instance.send(:setup_producer)
    end

    it 'triggers MessageInvalidError if empty string topic is provided' do
      expect(Rails.logger).to receive(:error).with(/Message is invalid/)

      # Send an invalid message to trigger an error (no topic provided)
      expect do
        avro_producer.produce('', valid_payload)
      end.to raise_error(WaterDrop::Errors::MessageInvalidError,
                         { topic: 'no topic provided' }.to_s)
    end

    it 'triggers MessageInvalidError if nil topic is provided' do
      expect(Rails.logger).to receive(:error).with(/Message is invalid/)

      # Send an invalid message to trigger an error (no topic provided)
      expect do
        avro_producer.produce(nil, valid_payload)
      end.to raise_error(WaterDrop::Errors::MessageInvalidError,
                         { topic: 'no topic provided' }.to_s)
    end

    it 'triggers MessageInvalidError if no valid payload is provided' do
      expect(Rails.logger).to receive(:error).with(/Message is invalid/)

      # Payloads larger than 1Mb are not allowed
      large_payload = 'a' * ((1 * 1024 * 1024) + 1) # 1MB + 1 byte

      allow(avro_producer).to receive(:encode_payload).and_return(large_payload)

      # Send an invalid message to trigger an error (no payload provided)
      expect do
        VCR.use_cassette('kafka/topics') do
          avro_producer.produce(topic, large_payload)
        end
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
        avro_producer.produce(topic, valid_payload)
      end.to raise_error(StandardError)
    end

    it 'logs a message when a ProducerError occurs' do
      expect(Rails.logger).to receive(:error).with(/Producer error/)
      # Simulate an error occurring in the producer
      allow(avro_producer.producer).to receive(:produce_sync)
        .and_raise(WaterDrop::Errors::ProduceError)

      # Trigger the error and handle it
      VCR.use_cassette('kafka/topics') do
        expect do
          avro_producer.produce(topic, valid_payload)
        end.to raise_error(WaterDrop::Errors::ProduceError)
      end
    end

    it 'logs a message when a SchemaValidationError occurs' do
      expect(Rails.logger).to receive(:error).with(/Schema validation error/)
      # Simulate a schema validation error
      # allow(Avro::SchemaValidator).to receive(:validate!).and_raise(Avro::SchemaValidator::ValidationError)

      # Trigger the error using an invalid schema
      VCR.use_cassette('kafka/topics') do
        expect do
          avro_producer.produce(topic, invalid_payload)
        end.to raise_error(Avro::SchemaValidator::ValidationError)
      end
    end

    it 'raises ValidationErrors when FormTrace validation fails' do
      invalid_form_data = {
        # Missing required fields: current_id, vasi_id, system_name, submission_name, state, timestamp
        'prior_id' => 'prior-123'
      }

      expect do
        avro_producer.produce('topic-1', invalid_form_data)
      end.to raise_error(Common::Exceptions::ValidationErrors)
    end
  end

  describe '#encode_payload' do
    it 'encodes the payload using the specified schema' do
      avro_producer.instance_variable_set(:@schema_id, 5)
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
