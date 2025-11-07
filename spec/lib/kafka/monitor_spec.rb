# frozen_string_literal: true

require 'rails_helper'
require 'kafka/monitor'

RSpec.describe Kafka::Monitor do
  let(:monitor) { described_class.new }
  let(:topic) { 'submission_trace_form_status_change' }
  let(:payload) { { 'data' => { 'ICN' => '[REDACTED]' } } }
  let(:form_payload) do
    {
      'priorId' => nil,
      'currentId' => '12345',
      'nextId' => nil,
      'icn' => 'ICN123456',
      'vasiId' => '1234',
      'systemName' => 'VA_gov',
      'submissionName' => 'F1010EZ',
      'state' => 'received',
      'timestamp' => '2024-03-04T12:00:00Z',
      'additionalIds' => nil
    }
  end
  let(:statsd_client) { instance_double(StatsD) }
  let(:error) { StandardError.new('Something went wrong') }

  describe '#track_submission_success' do
    it 'tracks the submit success event' do
      expect(monitor).to receive(:track_request).with(
        'info',
        "Kafka::EventBusSubmissionJob submission succeeded for topic #{topic}",
        'api.kafka_service.submission.success',
        call_location: instance_of(Thread::Backtrace::Location),
        topic:,
        kafka_payload: payload,
        tags: []
      )
      monitor.track_submission_success(topic, payload)
    end

    it 'adds tags to the tracked request' do
      expect(StatsD).to receive(:increment).with(
        'api.kafka_service.submission.success',
        tags: array_including('form:F1010EZ', 'state:received')
      )
      monitor.track_submission_success(topic, form_payload)
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
        kafka_payload: payload,
        errors: error.message,
        tags: []
      )
      monitor.track_submission_failure(topic, payload, error)
    end

    it 'adds tags to the tracked request' do
      expect(StatsD).to receive(:increment).with(
        'api.kafka_service.submission.failure',
        tags: array_including('form:F1010EZ', 'state:received')
      )
      monitor.track_submission_failure(topic, form_payload, error)
    end
  end

  describe '#track_submission_exhaustion' do
    let(:msg) { { 'args' => [topic, payload] } }

    it 'logs sidekiq job exhaustion' do
      log = "Kafka::EventBusSubmissionJob for #{topic} exhausted!"
      exhausted_payload = {
        message: msg,
        kafka_payload: payload,
        topic:,
        tags: []
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

    it 'adds tags to the tracked request' do
      expect(StatsD).to receive(:increment).with(
        'api.kafka_service.exhausted',
        tags: array_including('form:F1010EZ', 'state:received')
      )
      monitor.track_submission_exhaustion(msg, topic, form_payload)
    end
  end
end
