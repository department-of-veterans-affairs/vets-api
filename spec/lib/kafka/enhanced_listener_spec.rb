# frozen_string_literal: true

require 'rails_helper'
require 'kafka/enhanced_listener'

RSpec.describe Kafka::EnhancedListener do
  let(:mock_statsd_client) { instance_double(Datadog::Statsd) }
  let(:listener) do
    described_class.new do |config|
      config.client = mock_statsd_client
      config.default_tags = ['environment:test']
      config.rd_kafka_metrics = [
        described_class::RdKafkaMetric.new(:broker_service_check, :brokers, 'brokers.state', 'state'),
        described_class::RdKafkaMetric.new(:count, :brokers, 'brokers.connects', 'connects'),
        described_class::RdKafkaMetric.new(:count, :brokers, 'brokers.disconnects', 'disconnects'),
        described_class::RdKafkaMetric.new(:gauge, :brokers, 'brokers.rxidle', 'rxidle')
      ]
    end
  end

  let(:event) do
    {
      statistics: {
        'brokers' => {
          'localhost:9092/1001' => {
            'nodename' => 'localhost:9092',
            'state' => 'UP',
            'connects' => 5,
            'disconnects' => 2,
            'rxidle' => 1_029_387_488
          }
        }
      }
    }
  end

  before do
    allow(mock_statsd_client).to receive(:service_check)
    allow(mock_statsd_client).to receive(:count)
    allow(mock_statsd_client).to receive(:gauge)
  end

  describe 'service check functionality' do
    context 'when broker state is UP' do
      it 'sends OK status to Datadog' do
        listener.on_statistics_emitted(event)

        expect(mock_statsd_client).to have_received(:service_check).with(
          'waterdrop.brokers.state',
          Datadog::Statsd::OK,
          { tags: ['environment:test', 'broker:localhost:9092'] }
        )
      end
    end

    context 'when broker state is INIT or TRY_CONNECT' do
      %w[INIT CONNECT].each do |state|
        context "with state #{state}" do
          before do
            event[:statistics]['brokers']['localhost:9092/1001']['state'] = state
          end

          it 'sends WARNING status to Datadog' do
            listener.on_statistics_emitted(event)

            expect(mock_statsd_client).to have_received(:service_check).with(
              'waterdrop.brokers.state',
              Datadog::Statsd::WARNING,
              { tags: ['environment:test', 'broker:localhost:9092'] }
            )
          end
        end
      end
    end

    context 'when broker state is DOWN' do
      before do
        event[:statistics]['brokers']['localhost:9092/1001']['state'] = 'DOWN'
      end

      it 'sends CRITICAL status to Datadog' do
        listener.on_statistics_emitted(event)

        expect(mock_statsd_client).to have_received(:service_check).with(
          'waterdrop.brokers.state',
          Datadog::Statsd::CRITICAL,
          { tags: ['environment:test', 'broker:localhost:9092'] }
        )
      end
    end

    context 'when broker state is unknown' do
      before do
        event[:statistics]['brokers']['localhost:9092/1001']['state'] = 'APIVERSION_QUERY'
      end

      it 'sends UNKNOWN status to Datadog' do
        listener.on_statistics_emitted(event)

        expect(mock_statsd_client).to have_received(:service_check).with(
          'waterdrop.brokers.state',
          Datadog::Statsd::UNKNOWN,
          { tags: ['environment:test', 'broker:localhost:9092'] }
        )
      end
    end
  end

  describe 'count metrics' do
    before do
      event[:statistics]['brokers']['localhost:9092/1001']['connects'] = 10
      event[:statistics]['brokers']['localhost:9092/1001']['disconnects'] = 3
    end

    it 'sends count metrics for connects and disconnects' do
      listener.on_statistics_emitted(event)

      expect(mock_statsd_client).to have_received(:count).with(
        'waterdrop.brokers.connects',
        10,
        { tags: ['environment:test', 'broker:localhost:9092'] }
      )

      expect(mock_statsd_client).to have_received(:count).with(
        'waterdrop.brokers.disconnects',
        3,
        { tags: ['environment:test', 'broker:localhost:9092'] }
      )
    end
  end

  describe 'gauge metrics' do
    before do
      event[:statistics]['brokers']['localhost:9092/1001']['rxidle'] = 1_234_567_890
    end

    it 'sends gauge metrics for rxidle' do
      listener.on_statistics_emitted(event)

      expect(mock_statsd_client).to have_received(:gauge).with(
        'waterdrop.brokers.rxidle',
        1_234_567_890,
        { tags: ['environment:test', 'broker:localhost:9092'] }
      )
    end
  end

  describe 'multiple broker handling' do
    let(:event_with_multiple_brokers) do
      {
        statistics: {
          'brokers' => {
            'localhost:9092/1001' => {
              'nodename' => 'localhost:9092',
              'state' => 'UP',
              'connects' => 5
            },
            'localhost:9093/1002' => {
              'nodename' => 'localhost:9093',
              'state' => 'DOWN',
              'disconnects' => 1
            }
          }
        }
      }
    end

    it 'sends service checks and counts for all brokers' do
      listener.on_statistics_emitted(event_with_multiple_brokers)
      expect(mock_statsd_client).to have_received(:service_check).with(
        'waterdrop.brokers.state',
        Datadog::Statsd::OK,
        { tags: ['environment:test', 'broker:localhost:9092'] }
      )
      expect(mock_statsd_client).to have_received(:service_check).with(
        'waterdrop.brokers.state',
        Datadog::Statsd::CRITICAL,
        { tags: ['environment:test', 'broker:localhost:9093'] }
      )
      expect(mock_statsd_client).to have_received(:count).with(
        'waterdrop.brokers.connects',
        5,
        { tags: ['environment:test', 'broker:localhost:9092'] }
      )
      expect(mock_statsd_client).to have_received(:count).with(
        'waterdrop.brokers.disconnects',
        1,
        { tags: ['environment:test', 'broker:localhost:9093'] }
      )
    end
  end

  describe 'integration with ProducerManager' do
    let(:producer) { instance_double(WaterDrop::Producer) }
    let(:monitor) { instance_double(WaterDrop::Instrumentation::Monitor) }

    before do
      allow(WaterDrop::Producer).to receive(:new).and_return(producer)
      allow(producer).to receive(:monitor).and_return(monitor)
      allow(monitor).to receive(:subscribe)
      Singleton.__init__(Kafka::ProducerManager)
    end

    after do
      # Force singleton reset to ensure clean state
      Singleton.__init__(Kafka::ProducerManager)
    end

    it 'subscribes the listener to the producer monitor' do
      Kafka::ProducerManager.instance

      expect(monitor).to have_received(:subscribe).with(instance_of(described_class))
    end
  end
end
