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
        with_settings(Settings, vsp_environment: 'production') do
          expect(Kafka.redact_icn(input)).to eq(expected)
        end
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
        with_settings(Settings, vsp_environment: 'production') do
          expect(Kafka.redact_icn(input)).to eq(expected)
        end
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
        with_settings(Settings, vsp_environment: 'production') do
          expect(Kafka.redact_icn(input)).to eq(expected)
        end
      end
    end

    context 'with a hash containing no ICN' do
      let(:input) { { 'name' => 'test', 'data' => { 'value' => 123 } } }

      it 'returns the hash unchanged' do
        with_settings(Settings, vsp_environment: 'production') do
          expect(Kafka.redact_icn(input)).to eq(input)
        end
      end
    end

    context 'with a non-hash input' do
      let(:input) { 'not a hash' }

      it 'returns the input unchanged' do
        with_settings(Settings, vsp_environment: 'production') do
          expect(Kafka.redact_icn(input)).to eq(input)
        end
      end
    end

    context 'in a non-production vsp environment' do
      let(:input) { { 'icn' => '12345', 'name' => 'test' } }

      it 'returns the input unchanged' do
        with_settings(Settings, vsp_environment: 'staging') do
          expect(Kafka.redact_icn(input)).to eq(input)
        end
      end
    end
  end

  describe '#submit_test_event' do
    let(:icn) { '154786' }
    let(:current_id) { 'eded0764-7f5f-46c5-b40f-3c24335bf24f' }
    let(:submission_name) { '21P-527EZ' }
    let(:state) { 'sent' }
    let(:next_id) { '123456' }
    let(:prior_id) { '789012' }
    let(:payload) do
      { 'currentId' => current_id,
        'icn' => icn,
        'nextId' => next_id,
        'priorId' => prior_id,
        'state' => 'sent',
        'submissionName' => 'F527EZ',
        'systemName' => 'VA_gov',
        'timestamp' => Time.zone.now.iso8601,
        'vasiId' => '2103' }
    end

    context 'when payload is valid' do
      let(:expected_valid_output) do
        { 'data' => payload }
      end

      it 'kicks off Event Bus Submission Job' do
        VCR.use_cassette('kafka/topics') do
          expect(Kafka::EventBusSubmissionJob).to receive(:perform_async).with(expected_valid_output, true)
          expect(Kafka::ProducerManager.instance.producer).to receive(:produce_sync)
          Kafka.submit_test_event(payload)
          Kafka::AvroProducer.new.produce('submission_trace_mock_test', expected_valid_output)
        end
      end
    end

    context 'when payload is invalid' do
      it 'raises validation error' do
        invalid_payload = payload.merge({ data: { 'icn' => 123 } })
        expect do
          Kafka.submit_test_event(invalid_payload)
        end.to raise_error(Common::Exceptions::ValidationErrors)
      end
    end
  end

  describe '#submit_event' do
    let(:icn) { '154786' }
    let(:current_id) { 'eded0764-7f5f-46c5-b40f-3c24335bf24f' }
    let(:submission_name) { '21P-527EZ' }
    let(:state) { 'sent' }
    let(:next_id) { '123456' }
    let(:prior_id) { '789012' }
    let(:additional_ids) { %w[123 456] }
    let(:expected_valid_output) do
      { 'currentId' => current_id,
        'icn' => icn,
        'nextId' => next_id,
        'priorId' => prior_id,
        'state' => 'sent',
        'submissionName' => 'F527EZ',
        'systemName' => 'VA_gov',
        'timestamp' => Time.zone.now.iso8601,
        'vasiId' => '2103',
        'additionalIds' => %w[123 456] }
    end

    after { Kafka::ProducerManager.instance.producer.client.reset }

    context 'when payload is valid' do
      it 'kicks off Event Bus Submission Job' do
        VCR.use_cassette('kafka/topics') do
          expect(Kafka::EventBusSubmissionJob).to receive(:perform_async).with(expected_valid_output, false)
          expect(Kafka::ProducerManager.instance.producer).to receive(:produce_sync)
          Kafka.submit_event(icn:, prior_id:, current_id:, next_id:, submission_name:, state:, additional_ids:)
          Kafka::AvroProducer.new.produce('submission_trace_form_status_change_test', expected_valid_output)
        end
      end
    end

    context 'when payload is invalid' do
      let(:state) { 'MALFORMED_STATE' }

      it 'raises validation error' do
        expect do
          Kafka.submit_event(icn:, current_id:, next_id:, submission_name:, state:)
        end.to raise_error(Common::Exceptions::ValidationErrors)
      end
    end
  end
end
