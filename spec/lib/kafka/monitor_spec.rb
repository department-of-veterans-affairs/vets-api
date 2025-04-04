# frozen_string_literal: true

require 'rails_helper'
require 'kafka/monitor'

RSpec.describe Kafka::Monitor do
  let(:monitor) { described_class.new }
  let(:topic) { 'kafka-topic' }
  let(:payload) { { 'data' => { 'ICN' => '123' } } }
  let(:error) { StandardError.new('Something went wrong') }

  describe '#track_submission_success' do
    it 'tracks the submit success event' do
      expect(monitor).to receive(:track_request).with(
        'info',
        "Kafka::EventBusSubmissionJob submission succeeded for topic #{topic}",
        'api.kafka_service.submission.success',
        call_location: instance_of(Thread::Backtrace::Location),
        topic:,
        payload:
      )
      monitor.track_submission_success(topic, payload)
    end
  end

  describe '#track_submission_failure' do
    it 'tracks the submit failure event' do
      expect(monitor).to receive(:track_request).with(
        'error',
        "Kafka::EventBusSubmissionJob submission failed for topic #{topic}",
        'api.kafka_service.submission.failure',
        call_location: instance_of(Thread::Backtrace::Location),
        topic:,
        payload:,
        errors: error.message
      )
      monitor.track_submission_failure(topic, payload, error)
    end
  end

  describe '#track_submission_exhaustion' do
    it 'logs sidekiq job exhaustion' do
      msg = { 'args' => [topic, payload] }

      log = "Kafka::EventBusSubmissionJob for #{topic} exhausted!"
      exhausted_payload = {
        message: msg,
        payload:,
        topic: 'kafka-topic'
      }

      expect(monitor).to receive(:track_request).with(
        'error',
        log,
        'api.kafka_service.exhausted',
        call_location: anything,
        **exhausted_payload
      )

      monitor.track_submission_exhaustion(msg, topic, payload)
    end
  end
end
