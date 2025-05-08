# frozen_string_literal: true

require 'rails_helper'
require 'kafka/models/test_form_trace'

RSpec.describe Kafka::TestFormTrace do
  let(:valid_attributes) do
    { 'data' => {
      'current_id' => '123',
      'vasi_id' => 'vasi-456',
      'system_name' => 'Lighthouse',
      'submission_name' => 'F1010EZ',
      'state' => 'received',
      'timestamp' => '2024-03-13T10:00:00Z'
    } }
  end

  describe 'validations' do
    subject { described_class.new(valid_attributes) }

    it 'is valid with valid attributes' do
      expect(subject).to be_valid
      expect(subject.data['system_name']).to eq('Lighthouse')
    end

    context 'when data is not present' do
      let(:payload) { {} }

      it 'throws validation error' do
        trace = described_class.new(payload)
        expect(trace).not_to be_valid
      end
    end

    context 'when data fields are not strings' do
      it 'requires' do
        trace = described_class.new(valid_attributes.merge({ data: { current_id: 123 } }))
        expect(trace).not_to be_valid
        expect(trace.errors['data']).to include('must be a hash with all string keys and values')
      end
    end
  end
end
