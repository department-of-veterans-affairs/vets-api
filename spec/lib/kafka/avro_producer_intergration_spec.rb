require 'rails_helper'
require 'kafka/avro_producer'
require 'testcontainers'
require 'net/http'

fdescribe Kafka::AvroProducer, type: :integration do
  compose = Testcontainers::ComposeContainer.new(filepath: 'spec/fixtures/kafka/')
  let(:detected_errors) { [] }
  let(:acknowledged_messages) { [] }

  let(:producer) do
    WaterDrop::Producer.new do |config|
      config.deliver = true
      config.kafka = {
        'bootstrap.servers': 'localhost:19092',
        'request.required.acks': 1,
        'message.timeout.ms': 5000
      }
    end
  end

  let(:unreachable_producer) do
    WaterDrop::Producer.new do |config|
      config.deliver = true
      config.kafka = {
        'bootstrap.servers': 'localhost:29092', # Non-existent port
        'request.required.acks': 1,
        'message.timeout.ms': 1000,
        'socket.timeout.ms': 1000,
        'metadata.request.timeout.ms': 1000
      }
    end
  end

  let(:avro_producer) { described_class.new(producer: producer) }

  def execute_shell_command(command)
    stdout, stderr, status = Open3.capture3(command)
    p [stdout, stderr, status]
    raise "Command failed: #{stderr}" unless status.success?

    stdout
  end

  def register_schema
    schema_path = File.expand_path('../../fixtures/avro_schemas/test.avsc', __dir__)
    command = <<~SHELL
      jq '. | {schema: tojson}' #{schema_path} | \
      curl -X POST http://localhost:8081/subjects/test-value/versions \
        -H "Content-Type:application/json" \
        -d @- \
        --silent
    SHELL

    response = execute_shell_command(command)
    raise "Failed to register schema: #{response}" unless response.include?('id')
  end

  def verify_schema_registered
    command = 'curl -s http://localhost:8081/subjects/test-value/versions/1'
    execute_shell_command(command)
  end

  before(:all) do
    VCR.configure do |c|
      c.ignore_request do |request|
        uri = URI(request.uri)
        [19_092, 8081].include?(uri.port)
      end
    end

    # Start containers
    compose.start
    compose.wait_for_tcp_port(host: 'localhost', port: 19_092)
    compose.wait_for_http(url: 'http://localhost:8081/subjects/')

    # Give Schema Registry time to start up
    # sleep(5)

    # Register schema
    register_schema
    verify_schema_registered

    # Create test topic
    compose.exec(
      service_name: 'kafka',
      command: 'kafka-topics.sh --create --topic test --partitions 1 --replication-factor 1 --if-not-exists --bootstrap-server localhost:19092'
    )
  end

  after(:all) do
    compose.stop
  end

  before do
    # Set up error monitoring
    producer.monitor.subscribe('error.occurred') do |event|
      detected_errors << event
    end

    # Set up message acknowledgment monitoring
    producer.monitor.subscribe('message.acknowledged') do |event|
      acknowledged_messages << event
    end
  end

  after do
    detected_errors.clear
    acknowledged_messages.clear
    # avro_producer.producer.client.reset
  end

  context 'successful message production' do
    it 'produces a valid message and receives acknowledgment' do
      message = { 'data' => { 'key' => 'value1' } }
      avro_producer.produce('test', message)

      expect(acknowledged_messages.size).to eq(1)
      expect(acknowledged_messages.first[:topic]).to eq('test')
    end
  end

  context 'schema validation' do
    it 'raises ValidationError for invalid message schema' do
      invalid_message = { 'invalid_field' => 'value' }

      expect do
        avro_producer.produce('test', invalid_message)
      end.to raise_error(Avro::SchemaValidator::ValidationError)

      # Avro validation errors are not caught by WaterDrop
      expect(detected_errors.size).to eq(0)
    end
  end

  context 'producer errors' do
    it 'handles message size too large' do
      large_payload = { 'data' => { 'key' => 'x' * 1_000_000 } }

      expect do
        avro_producer.produce('test', large_payload)
      end.to raise_error(WaterDrop::Errors::MessageInvalidError)

      # WaterDrop catches the error before attempting to send the message
      expect(detected_errors.size).to eq(0)
    end

    it 'handles invalid topic name' do
      expect do
        avro_producer.produce('invalid/topic', { 'data' => { 'key' => 'value' } })
      end.to raise_error(AvroTurf::SchemaNotFoundError)

      # Avro catches the error before WaterDrop attempts to send the message
      expect(detected_errors.size).to eq(0)
    end
  end

  context 'network issues' do
    let(:producer_with_network_issues) { described_class.new(producer: unreachable_producer) }

    before do
      unreachable_producer.monitor.subscribe('error.occurred') do |event|
        detected_errors << event
      end
    end

    it 'handles connection timeout' do
      expect do
        producer_with_network_issues.produce('test', { 'data' => { 'key' => 'value' } })
      end.to raise_error(WaterDrop::Errors::ProduceError)

      errors = detected_errors.map { |e| e.payload[:error].message }

      expect(detected_errors.size).to be >= 4
      expect(errors).to include(/Broker transport failure/)
      expect(errors).to include(/All broker connections are down/)
      expect(errors).to include(/Message timed out/)
    end
  end

  context 'instrumentation' do
    it 'monitors message lifecycle' do
      message = { 'data' => { 'key' => 'value1' } }
      avro_producer.produce('test', message)

      expect(acknowledged_messages.size).to eq(1)
      event = acknowledged_messages.first

      expect(event[:topic]).to eq('test')
      expect(event[:partition]).to be_a(Integer)
      expect(event[:offset]).to be_a(Integer)
    end
  end
end
