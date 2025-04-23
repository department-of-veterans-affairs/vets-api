# frozen_string_literal: true

require 'rails_helper'
require 'kafka/models/form_trace'

RSpec.describe Kafka::FormTrace do
  let(:valid_attributes) do
    {
      prior_id: nil,
      current_id: '123',
      next_id: nil,
      icn: nil,
      vasi_id: 'vasi-456',
      system_name: 'Lighthouse',
      submission_name: 'F1010EZ',
      state: 'received',
      timestamp: '2024-03-13T10:00:00Z',
      additional_ids: nil
    }
  end

  describe '#truncate_form_id' do
    context 'when form_id contains a dash' do
      it 'returns the truncated form ID with "F" prefix' do
        expect(Kafka::FormTrace.new(valid_attributes).truncate_form_id('21P-527EZ')).to eq('F527EZ')
      end
    end

    context 'when form_id does not contain a dash' do
      it 'returns the form ID with "F" prefix' do
        expect(Kafka::FormTrace.new(valid_attributes).truncate_form_id('1010EZ')).to eq('F1010EZ')
      end
    end

    context 'when form_id is already the correct format' do
      it 'returns the form ID with "F" prefix' do
        expect(Kafka::FormTrace.new(valid_attributes).truncate_form_id('F1010EZ')).to eq('F1010EZ')
      end
    end
  end

  describe 'validations' do
    subject { described_class.new(valid_attributes) }

    it 'is valid with valid attributes' do
      expect(subject).to be_valid
      expect(subject.system_name).to eq('Lighthouse')
    end

    context 'when optional fields are provided' do
      let(:full_attributes) do
        valid_attributes.merge(
          prior_id: 'prior-123',
          next_id: 'next-456',
          icn: 'icn-789',
          additional_ids: 'extra-123,extra-456'
        )
      end

      it 'is valid with all fields' do
        trace = described_class.new(full_attributes)
        expect(trace).to be_valid
        expect(trace.system_name).to eq('Lighthouse')
      end
    end

    context 'required fields' do
      %i[current_id vasi_id system_name submission_name state timestamp].each do |field|
        it "requires #{field}" do
          trace = described_class.new(valid_attributes.except(field))
          expect(trace).not_to be_valid
          expect(trace.errors[field]).to include("can't be blank")
        end
      end
    end

    context 'enum validations' do
      it 'validates system_name inclusion' do
        trace = described_class.new(valid_attributes.merge(system_name: 'InvalidSystem'))
        expect(trace).not_to be_valid
        expect(trace.errors[:system_name]).to include('is not included in the list')
      end

      it 'validates submission_name inclusion' do
        trace = described_class.new(valid_attributes.merge(submission_name: 'InvalidForm'))
        expect(trace).not_to be_valid
        expect(trace.errors[:submission_name]).to include('is not included in the list')
      end

      it 'validates state inclusion' do
        trace = described_class.new(valid_attributes.merge(state: 'InvalidState'))
        expect(trace).not_to be_valid
        expect(trace.errors[:state]).to include('is not included in the list')
      end

      it 'accepts valid system_name values' do
        described_class::SYSTEM_NAMES.each do |name|
          trace = described_class.new(valid_attributes.merge(system_name: name))
          expect(trace).to be_valid
        end
      end

      it 'accepts valid submission_name values' do
        described_class::SUBMISSION_NAMES.each do |name|
          trace = described_class.new(valid_attributes.merge(submission_name: name))
          expect(trace).to be_valid
        end
      end

      it 'accepts valid state values' do
        described_class::STATES.each do |state|
          trace = described_class.new(valid_attributes.merge(state:))
          expect(trace).to be_valid
        end
      end
    end
  end
end
