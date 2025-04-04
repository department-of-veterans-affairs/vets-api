# frozen_string_literal: true

require 'rails_helper'
require 'kafka/sidekiq/event_bus_submission_job'
require 'kafka/avro_producer'

RSpec.describe Kafka::EventBusSubmissionJob, type: :job do
  let(:topic) { 'form_submission_service' }
  let(:payload) { { 'data' => { 'ICN' => 'id' } } }
  let(:monitor) { instance_double(Kafka::Monitor) }
  let(:producer) { instance_double(Kafka::AvroProducer) }

  before do
    allow(Kafka::Monitor).to receive(:new).and_return(monitor)
    allow(Kafka::AvroProducer).to receive(:new).and_return(producer)
    allow(producer).to receive(:produce)
    allow(monitor).to receive(:track_submission_success)
    allow(monitor).to receive(:track_submission_failure)
  end

  describe '#perform' do
    it 'produces a message to the Kafka topic and tracks success' do
      described_class.new.perform(topic, payload)
      expect(producer).to have_received(:produce).with(topic, payload)
      expect(monitor).to have_received(:track_submission_success).with(topic, payload)
    end

    context 'when an error occurs during production' do
      let(:error) { StandardError.new('Error') }

      before do
        allow(producer).to receive(:produce).and_raise(error)
      end

      it 'tracks the failure and raises the error' do
        expect do
          described_class.new.perform(topic, payload)
        end.to raise_error(StandardError, 'Error')
        expect(monitor).to have_received(:track_submission_failure).with(topic, payload, error)
      end
    end
  end
end
