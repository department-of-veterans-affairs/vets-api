# frozen_string_literal: true

require 'rails_helper'
require 'kafka/concerns/topic'

RSpec.describe Kafka::Topic do
  let(:dummy_class) { Class.new { include Kafka::Topic } }
  let(:instance) { dummy_class.new }

  describe '#get_topic' do
    context 'when use_test_topic is false' do
      it 'returns the production topic name' do
        expect(instance.get_topic(use_test_topic: false)).to eq('submission_trace_form_status_change_test')
      end
    end

    context 'when use_test_topic is true' do
      it 'returns the test topic name' do
        expect(instance.get_topic(use_test_topic: true)).to eq('submission_trace_mock_test')
      end
    end
  end

  describe '#redact_icn' do
    context 'with a simple hash containing ICN' do
      let(:input) { { 'icn' => '12345', 'name' => 'test' } }
      let(:expected) { { 'icn' => '[REDACTED]', 'name' => 'test' } }

      it 'redacts the ICN value' do
        expect(instance.redact_icn(input)).to eq(expected)
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
        expect(instance.redact_icn(input)).to eq(expected)
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
        expect(instance.redact_icn(input)).to eq(expected)
      end
    end

    context 'with a hash containing no ICN' do
      let(:input) { { 'name' => 'test', 'data' => { 'value' => 123 } } }

      it 'returns the hash unchanged' do
        expect(instance.redact_icn(input)).to eq(input)
      end
    end

    context 'with a non-hash input' do
      let(:input) { 'not a hash' }

      it 'returns the input unchanged' do
        expect(instance.redact_icn(input)).to eq(input)
      end
    end
  end
end
