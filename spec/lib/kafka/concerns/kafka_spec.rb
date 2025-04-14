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

  describe '#truncate_form_id' do
    context 'when form_id contains a dash' do
      it 'returns the truncated form ID with "F" prefix' do
        expect(Kafka.truncate_form_id('21P-527EZ')).to eq('F527EZ')
      end
    end

    context 'when form_id does not contain a dash' do
      it 'returns the form ID with "F" prefix' do
        expect(Kafka.truncate_form_id('1010EZ')).to eq('F1010EZ')
      end
    end
  end
end
