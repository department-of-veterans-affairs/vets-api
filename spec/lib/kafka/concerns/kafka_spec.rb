# frozen_string_literal: true

require 'rails_helper'
require 'kafka/concerns/kafka'

RSpec.describe Kafka do
  describe '#get_topic' do
    context 'when use_test_topic is false' do
      it 'returns the production topic name' do
        expect(Kafka.get_topic(use_test_topic: false)).to eq('submission_trace_form_status_change_test')
      end
    end

    context 'when use_test_topic is true' do
      it 'returns the test topic name' do
        expect(Kafka.get_topic(use_test_topic: true)).to eq('submission_trace_mock_test')
      end
    end
  end

  describe '#redact_icn' do
    context 'with a simple hash containing ICN' do
      let(:input) { { 'icn' => '12345', 'name' => 'test' } }
      let(:expected) { { 'icn' => '[REDACTED]', 'name' => 'test' } }

      it 'redacts the ICN value' do
        expect(Kafka.redact_icn(input)).to eq(expected)
      end
    end

    context 'with a nested hash containing ICN' do
      let(:input) do
        {
          'user' => {
            'ICN' => '12345',
            'details' => {
              'icn' => '5678'
            }
          }
        }
      end
      let(:expected) do
        {
          'user' => {
            'ICN' => '[REDACTED]',
            'details' => {
              'icn' => '[REDACTED]'
            }
          }
        }
      end

      it 'redacts the nested ICN value' do
        expect(Kafka.redact_icn(input)).to eq(expected)
      end
    end

    context 'with an array of hashes containing ICN' do
      let(:input) do
        {
          'users' => [
            { 'ICN' => '12345', 'name' => 'test1' },
            { 'ICN' => '67890', 'name' => 'test2' }
          ]
        }
      end
      let(:expected) do
        {
          'users' => [
            { 'ICN' => '[REDACTED]', 'name' => 'test1' },
            { 'ICN' => '[REDACTED]', 'name' => 'test2' }
          ]
        }
      end

      it 'redacts ICN values in the array' do
        expect(Kafka.redact_icn(input)).to eq(expected)
      end
    end

    context 'with a hash containing no ICN' do
      let(:input) { { 'name' => 'test', 'data' => { 'value' => 123 } } }

      it 'returns the hash unchanged' do
        expect(Kafka.redact_icn(input)).to eq(input)
      end
    end

    context 'with a non-hash input' do
      let(:input) { 'not a hash' }

      it 'returns the input unchanged' do
        expect(Kafka.redact_icn(input)).to eq(input)
      end
    end
  end

  describe '#submit_event' do
    let(:icn) { '' }
    let(:current_id) { 'eded0764-7f5f-46c5-b40f-3c24335bf24f' }
    let(:submission_name) { '21P-527EZ' }
    let(:state) { 'sent' }
    let(:next_id) { '123456' }
    let(:prior_id) { '789012' }
    let(:additional_ids) { %w[123 456] }
    let(:expected_valid_output) do
      { 'current_id' => current_id,
        'icn' => icn,
        'next_id' => next_id,
        'prior_id' => prior_id,
        'state' => 'sent',
        'submission_name' => 'F527EZ',
        'system_name' => 'VA_gov',
        'timestamp' => Time.zone.now.iso8601,
        'vasi_id' => '2103',
        'additional_ids' => %w[123 456] }
    end

    context 'when payload is valid' do
      context 'when using non-test topic' do
        it 'kicks off Event Bus Submission Job' do
          expect(Kafka::EventBusSubmissionJob).to receive(:perform_async).with(expected_valid_output, false)

          Kafka.submit_event(icn:, prior_id:, current_id:, next_id:, submission_name:, state:, additional_ids:,
                             use_test_topic: false)
        end
      end

      context 'when using test topic' do
        it 'kicks off Event Bus Submission Job' do
          test_topic_expected_output = expected_valid_output.merge('submission_name' => submission_name)
          test_topic_expected_output = { 'data' => test_topic_expected_output }
          expect(Kafka::EventBusSubmissionJob).to receive(:perform_async).with(test_topic_expected_output, true)

          Kafka.submit_event(icn:, prior_id:, current_id:, next_id:, submission_name:, state:, additional_ids:,
                             use_test_topic: true)
        end
      end
    end

    context 'when payload is invalid' do
      let(:state) { 'MALFORMED_STATE' }

      context 'when using non-test topic' do
        it 'raises validation error' do
          expect do
            Kafka.submit_event(icn:, current_id:, next_id:, submission_name:, state:, use_test_topic: false)
          end.to raise_error(Common::Exceptions::ValidationErrors)
        end
      end

      context 'when using test topic' do
        it 'kicks off Event Bus Submission Job' do
          expect(Kafka::EventBusSubmissionJob).to receive(:perform_async)

          Kafka.submit_event(icn:, current_id:, next_id:, submission_name:, state:, use_test_topic: true)
        end
      end
    end
  end
end
