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
      comments: ['Well-controlled with medication.']
    )
  end

  describe '.new' do
    it 'returns correct JSONAPI structure with all attributes' do
      result = described_class.new(condition).serializable_hash[:data]

      expect(result[:id]).to eq('condition-123')
      expect(result[:type]).to eq(:condition)
      expect(result[:attributes]).to include(
        date: '2025-01-15T10:30:00Z',
        name: 'Essential hypertension',
        provider: 'Dr. Smith, John',
        facility: 'VA Medical Center',
        comments: ['Well-controlled with medication.']
      )
    end

    it 'handles array of conditions' do
      conditions = [condition, condition]
      result = described_class.new(conditions).serializable_hash[:data]

      expect(result).to be_an(Array)
      expect(result.size).to eq(2)
      expect(result.first[:type]).to eq(:condition)
    end
  end
end
