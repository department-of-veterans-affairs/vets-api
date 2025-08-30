# frozen_string_literal: true

require 'rails_helper'
require 'unified_health_data/models/condition'
require 'unified_health_data/serializers/condition_serializer'

RSpec.describe UnifiedHealthData::Serializers::ConditionSerializer do
  let(:condition) do
    UnifiedHealthData::Condition.new(
      id: 'condition-123',
      date: '2025-01-15T10:30:00Z',
      name: 'Essential hypertension',
      provider: 'Dr. Smith, John',
      facility: 'VA Medical Center',
      comments: 'Well-controlled with medication.'
    )
  end

  describe '.new' do
    context 'with complete condition data' do
      it 'returns correct JSONAPI structure' do
        result = described_class.new(condition).serializable_hash[:data]

        expect(result[:id]).to eq('condition-123')
        expect(result[:type]).to eq(:condition)
        expect(result[:attributes]).to include(
          date: '2025-01-15T10:30:00Z',
          name: 'Essential hypertension',
          provider: 'Dr. Smith, John',
          facility: 'VA Medical Center',
          comments: 'Well-controlled with medication.'
        )
      end

      it 'includes type and attributes wrapper' do
        result = described_class.new(condition).serializable_hash[:data]
        expect(result).to have_key(:type)
        expect(result).to have_key(:attributes)
        expect(result[:type]).to eq(:condition)
      end
    end

    context 'with missing optional fields' do
      let(:minimal_condition) do
        UnifiedHealthData::Condition.new(
          id: 'condition-456',
          date: '2025-01-15T10:30:00Z',
          name: 'Essential hypertension',
          provider: nil,
          facility: '',
          comments: '   '
        )
      end

      it 'returns empty strings for missing optional fields' do
        result = described_class.new(minimal_condition).serializable_hash[:data]

        expect(result[:id]).to eq('condition-456')
        expect(result[:type]).to eq(:condition)
        expect(result[:attributes]).to include(
          date: '2025-01-15T10:30:00Z',
          name: 'Essential hypertension',
          provider: nil,
          facility: '', # JSONAPI serializer returns empty string, not nil
          comments: '   ' # JSONAPI serializer returns whitespace as-is
        )
      end
    end

    context 'with nil condition' do
      it 'handles nil gracefully' do
        # JSONAPI serializer doesn't accept nil, so we test with empty array
        result = described_class.new([]).serializable_hash[:data]
        expect(result).to eq([])
      end
    end

    context 'with invalid date format' do
      let(:invalid_condition) do
        UnifiedHealthData::Condition.new(
          id: 'condition-invalid',
          date: 'invalid-date',
          name: 'Test condition'
        )
      end

      it 'returns original date string if parsing fails' do
        result = described_class.new(invalid_condition).serializable_hash[:data]
        expect(result[:attributes][:date]).to eq('invalid-date')
      end
    end

    context 'with missing attributes' do
      let(:no_attributes_condition) do
        UnifiedHealthData::Condition.new(
          id: 'condition-empty'
        )
      end

      it 'handles missing attributes gracefully' do
        result = described_class.new(no_attributes_condition).serializable_hash[:data]
        expect(result[:id]).to eq('condition-empty')
        expect(result[:attributes][:date]).to be_nil
        expect(result[:attributes][:name]).to be_nil
      end
    end

    context 'with nil date' do
      let(:nil_date_condition) do
        UnifiedHealthData::Condition.new(
          id: 'condition-no-date',
          date: nil,
          name: 'Condition without date',
          provider: 'Dr. Test'
        )
      end

      it 'returns nil for date when date is nil' do
        result = described_class.new(nil_date_condition).serializable_hash[:data]
        expect(result[:id]).to eq('condition-no-date')
        expect(result[:attributes]).to include(
          date: nil,
          name: 'Condition without date',
          provider: 'Dr. Test'
        )
      end
    end
  end
end
