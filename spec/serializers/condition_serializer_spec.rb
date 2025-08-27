# frozen_string_literal: true

require 'rails_helper'
require 'unified_health_data/models/condition'

RSpec.describe ConditionSerializer do
  let(:condition_attributes) do
    UnifiedHealthData::ConditionAttributes.new(
      date: '2025-01-15T10:30:00Z',
      name: 'Essential hypertension',
      provider: 'Dr. Smith, John',
      facility: 'VA Medical Center',
      comments: 'Well-controlled with medication.'
    )
  end

  let(:condition) do
    UnifiedHealthData::Condition.new(
      id: 'condition-123',
      type: 'Condition',
      attributes: condition_attributes
    )
  end

  describe '.serialize' do
    context 'with complete condition data' do
      it 'returns correct JSON structure matching Simple JSON contract' do
        result = described_class.serialize(condition)

        expect(result).to include(
          id: 'condition-123',
          date: '2025-01-15T10:30:00Z',
          name: 'Essential hypertension',
          provider: 'Dr. Smith, John',
          facility: 'VA Medical Center',
          comments: 'Well-controlled with medication.'
        )
      end

      it 'does not include type wrapper' do
        result = described_class.serialize(condition)
        expect(result).not_to have_key(:type)
        expect(result).not_to have_key(:attributes)
      end
    end

    context 'with missing optional fields' do
      let(:minimal_attributes) do
        UnifiedHealthData::ConditionAttributes.new(
          date: '2025-01-15T10:30:00Z',
          name: 'Essential hypertension',
          provider: nil,
          facility: '',
          comments: '   '
        )
      end

      let(:minimal_condition) do
        UnifiedHealthData::Condition.new(
          id: 'condition-456',
          type: 'Condition',
          attributes: minimal_attributes
        )
      end

      it 'returns null for empty optional fields' do
        result = described_class.serialize(minimal_condition)

        expect(result).to include(
          id: 'condition-456',
          date: '2025-01-15T10:30:00Z',
          name: 'Essential hypertension',
          provider: nil,
          facility: nil,
          comments: nil
        )
      end
    end

    context 'with nil condition' do
      it 'returns empty hash' do
        result = described_class.serialize(nil)
        expect(result).to eq({})
      end
    end

    context 'with invalid date format' do
      let(:invalid_date_attributes) do
        UnifiedHealthData::ConditionAttributes.new(
          date: 'invalid-date',
          name: 'Test condition'
        )
      end

      let(:invalid_condition) do
        UnifiedHealthData::Condition.new(
          id: 'condition-invalid',
          attributes: invalid_date_attributes
        )
      end

      it 'returns original date string if parsing fails' do
        result = described_class.serialize(invalid_condition)
        expect(result[:date]).to eq('invalid-date')
      end
    end

    context 'with missing attributes' do
      let(:no_attributes_condition) do
        UnifiedHealthData::Condition.new(
          id: 'condition-empty'
        )
      end

      it 'handles missing attributes gracefully' do
        result = described_class.serialize(no_attributes_condition)
        expect(result[:id]).to eq('condition-empty')
        expect(result[:date]).to be_nil
        expect(result[:name]).to eq('')
      end
    end

    context 'with nil date' do
      let(:nil_date_attributes) do
        UnifiedHealthData::ConditionAttributes.new(
          date: nil,
          name: 'Condition without date',
          provider: 'Dr. Test'
        )
      end

      let(:nil_date_condition) do
        UnifiedHealthData::Condition.new(
          id: 'condition-no-date',
          attributes: nil_date_attributes
        )
      end

      it 'returns nil for date when date is nil' do
        result = described_class.serialize(nil_date_condition)
        expect(result).to include(
          id: 'condition-no-date',
          date: nil,
          name: 'Condition without date',
          provider: 'Dr. Test'
        )
      end
    end
  end
end
