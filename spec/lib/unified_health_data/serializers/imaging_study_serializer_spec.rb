# frozen_string_literal: true

require 'rails_helper'
require 'unified_health_data/models/imaging_study'
require 'unified_health_data/serializers/imaging_study_serializer'

RSpec.describe UnifiedHealthData::Serializers::ImagingStudySerializer do
  let(:imaging_study) do
    UnifiedHealthData::ImagingStudy.new(
      id: 'imaging-study-123',
      identifier: 'urn:oid:1.2.840.113619.2.123',
      status: 'available',
      modality: 'CT',
      date: '2025-01-15T10:30:00Z',
      sort_date: '2025-01-15T10:30:00Z',
      description: 'CT Scan of Chest',
      notes: ['Routine follow-up scan'],
      patient_id: '1012740414V122180',
      series_count: 2,
      image_count: 15,
      series: [
        { uid: 'series-1', number: 1, modality: 'CT', instances: [] }
      ]
    )
  end

  describe '.new' do
    it 'returns correct JSONAPI structure with all attributes' do
      result = described_class.new(imaging_study).serializable_hash[:data]

      expect(result[:id]).to eq('imaging-study-123')
      expect(result[:type]).to eq(:imaging_study)
      expect(result[:attributes]).to include(
        id: 'imaging-study-123',
        identifier: 'urn:oid:1.2.840.113619.2.123',
        status: 'available',
        modality: 'CT',
        date: '2025-01-15T10:30:00Z',
        description: 'CT Scan of Chest',
        notes: ['Routine follow-up scan'],
        patient_id: '1012740414V122180',
        series_count: 2,
        image_count: 15
      )
    end

    it 'does not include sort_date in serialized output' do
      result = described_class.new(imaging_study).serializable_hash[:data]

      expect(result[:attributes]).not_to have_key(:sort_date)
    end

    it 'includes series data' do
      result = described_class.new(imaging_study).serializable_hash[:data]

      expect(result[:attributes][:series]).to eq([
                                                   { uid: 'series-1',
                                                     number: 1,
                                                     modality: 'CT',
                                                     instances: [] }
                                                 ])
    end

    it 'handles array of imaging studies' do
      studies = [imaging_study, imaging_study]
      result = described_class.new(studies).serializable_hash[:data]

      expect(result).to be_an(Array)
      expect(result.size).to eq(2)
      expect(result.first[:type]).to eq(:imaging_study)
    end
  end
end
