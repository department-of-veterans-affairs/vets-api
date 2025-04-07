# frozen_string_literal: true

require 'rails_helper'
require 'kafka/monitor'

RSpec.describe Kafka::Monitor do
  let(:monitor) { described_class.new }
  let(:topic) { 'submission_trace_form_status_change_test' }
  let(:payload) { { 'data' => { 'ICN' => '123' } } }
  let(:malformed_payload) do
    { 'data' => { 'ICN' => '123', 'body' => { 'ICN' => '1234' } }, 'ICN' => '56789',
      'icn_array' => [{ 'icn' => '9999' }] }
  end
  let(:redacted_malformed_payload) do
    { 'data' => { 'ICN' => '[REDACTED]', 'body' => { 'ICN' => '[REDACTED]' } },
      'ICN' => '[REDACTED]', 'icn_array' => [{ 'icn' => '[REDACTED]' }] }
  end
  let(:redacted_payload) { { 'data' => { 'ICN' => '[REDACTED]' } } }
  let(:error) { StandardError.new('Something went wrong') }

  describe '#track_submission_success' do
    it 'tracks the submit success event' do
      expect(monitor).to receive(:track_request).with(
        'info',
        "Kafka::EventBusSubmissionJob submission succeeded for topic #{topic}",
        'api.kafka_service.submission.success',
        call_location: instance_of(Thread::Backtrace::Location),
        topic:,
        payload: redacted_payload
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
        payload: redacted_payload,
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
        payload: redacted_payload,
        topic:
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

  describe '#redact_icn' do
    it 'removes icn at any level of hash' do
      expect(monitor).to receive(:track_request).with(
        'info',
        "Kafka::EventBusSubmissionJob submission succeeded for topic #{topic}",
        'api.kafka_service.submission.success',
        call_location: instance_of(Thread::Backtrace::Location),
        topic:,
        payload: redacted_malformed_payload
      )
      monitor.track_submission_success(topic, malformed_payload)
    end
  end
end
