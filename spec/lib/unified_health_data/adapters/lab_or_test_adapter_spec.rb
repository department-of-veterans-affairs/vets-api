# frozen_string_literal: true

require 'rails_helper'
require 'unified_health_data/adapters/lab_or_test_adapter'

RSpec.describe UnifiedHealthData::Adapters::LabOrTestAdapter, type: :service do
  let(:adapter) { UnifiedHealthData::Adapters::LabOrTestAdapter.new }
  let(:labs_response) do
    file_path = Rails.root.join('spec', 'fixtures', 'unified_health_data', 'labs_response.json')
    JSON.parse(File.read(file_path))
  end
  let(:sample_response) do
    JSON.parse(Rails.root.join(
      'spec', 'fixtures', 'unified_health_data', 'sample_response.json'
    ).read)
  end

  before do
    allow(UnifiedHealthData::LabOrTest).to receive(:new).and_call_original
    allow(UnifiedHealthData::ReferenceRangeFormatter).to receive(:format).and_call_original
  end

  describe '#get_location' do
    it 'returns the organization name if present' do
      record = { 'resource' => { 'contained' => [{ 'resourceType' => 'Organization', 'name' => 'LabX' }] } }
      expect(adapter.send(:get_location, record)).to eq('LabX')
    end

    it 'returns nil if no organization' do
      record = { 'resource' => { 'contained' => [{ 'resourceType' => 'Other' }] } }
      expect(adapter.send(:get_location, record)).to be_nil
    end
  end

  describe '#get_ordered_by' do
    it 'returns practitioner full name if present' do
      record = { 'resource' => { 'contained' => [{ 'resourceType' => 'Practitioner',
                                                   'name' => [{ 'given' => ['A'], 'family' => 'B' }] }] } }
      expect(adapter.send(:get_ordered_by, record)).to eq('A B')
    end

    it 'returns nil if no practitioner' do
      record = { 'resource' => { 'contained' => [{ 'resourceType' => 'Other' }] } }
      expect(adapter.send(:get_ordered_by, record)).to be_nil
    end
  end

  describe '#format_observation_value' do
    it 'returns quantity type and text' do
      obs = { 'valueQuantity' => { 'value' => 5, 'unit' => 'mg' } }
      expect(adapter.send(:format_observation_value, obs)).to eq({ type: 'quantity', text: '5 mg' })
    end

    it 'includes the less-than comparator in the text result when present' do
      obs = { 'valueQuantity' => { 'value' => 50, 'comparator' => '<', 'unit' => 'mmol/L' } }
      expect(adapter.send(:format_observation_value, obs)).to eq({ type: 'quantity', text: '<50 mmol/L' })
    end

    it 'includes the greater-than comparator in the text result when present' do
      obs = { 'valueQuantity' => { 'value' => 120, 'comparator' => '>', 'unit' => 'mg/dL' } }
      expect(adapter.send(:format_observation_value, obs)).to eq({ type: 'quantity', text: '>120 mg/dL' })
    end

    it 'includes the less-than-or-equal comparator in the text result when present' do
      obs = { 'valueQuantity' => { 'value' => 6.5, 'comparator' => '<=', 'unit' => '%' } }
      expect(adapter.send(:format_observation_value, obs)).to eq({ type: 'quantity', text: '<=6.5 %' })
    end

    it 'includes the greater-than-or-equal comparator in the text result when present' do
      obs = { 'valueQuantity' => { 'value' => 8.0, 'comparator' => '>=', 'unit' => 'ng/mL' } }
      expect(adapter.send(:format_observation_value, obs)).to eq({ type: 'quantity', text: '>=8.0 ng/mL' })
    end

    it 'includes the "sufficient to achieve" (ad) comparator in the text result when present' do
      obs = { 'valueQuantity' => { 'value' => 12.3, 'comparator' => 'ad', 'unit' => 'mol/L' } }
      expect(adapter.send(:format_observation_value, obs)).to eq({ type: 'quantity', text: 'ad12.3 mol/L' })
    end

    it 'handles valueQuantity with no unit correctly' do
      obs = { 'valueQuantity' => { 'value' => 10, 'comparator' => '>' } }
      expect(adapter.send(:format_observation_value, obs)).to eq({ type: 'quantity', text: '>10' })
    end

    it 'handles empty or nil comparator gracefully' do
      obs = { 'valueQuantity' => { 'value' => 75, 'comparator' => '', 'unit' => 'pg/mL' } }
      expect(adapter.send(:format_observation_value, obs)).to eq({ type: 'quantity', text: '75 pg/mL' })
    end

    it 'returns codeable-concept type and text' do
      obs = { 'valueCodeableConcept' => { 'text' => 'POS' } }
      expect(adapter.send(:format_observation_value, obs)).to eq({ type: 'codeable-concept', text: 'POS' })
    end

    it 'returns string type and text' do
      obs = { 'valueString' => 'abc' }
      expect(adapter.send(:format_observation_value, obs)).to eq({ type: 'string', text: 'abc' })
    end

    it 'returns date-time type and text' do
      obs = { 'valueDateTime' => '2024-06-01T00:00:00Z' }
      expect(adapter.send(:format_observation_value, obs)).to eq({ type: 'date-time', text: '2024-06-01T00:00:00Z' })
    end

    it 'returns nils for unsupported types' do
      obs = {}
      expect(adapter.send(:format_observation_value, obs)).to eq({ type: nil, text: nil })
    end
  end

  describe '#get_body_site' do
    context 'when contained is nil' do
      it 'returns an empty string' do
        resource = { 'basedOn' => [{ 'reference' => 'ServiceRequest/123' }] }
        contained = nil

        result = adapter.send(:get_body_site, resource, contained)

        expect(result).to eq('')
      end
    end

    context 'when basedOn is nil' do
      it 'returns an empty string' do
        resource = {}
        contained = [{ 'resourceType' => 'ServiceRequest', 'id' => '123' }]

        result = adapter.send(:get_body_site, resource, contained)

        expect(result).to eq('')
      end
    end
  end

  describe '#get_sample_tested' do
    context 'when contained is nil' do
      it 'returns an empty string' do
        record = { 'specimen' => { 'reference' => 'Specimen/123' } }
        contained = nil

        result = adapter.send(:get_sample_tested, record, contained)

        expect(result).to eq('')
      end
    end

    context 'when specimen is nil' do
      it 'returns an empty string' do
        record = {}
        contained = [{ 'resourceType' => 'Specimen', 'id' => '123' }]

        result = adapter.send(:get_sample_tested, record, contained)

        expect(result).to eq('')
      end
    end

    context 'when specimen reference is not found in contained array' do
      it 'returns an empty string' do
        record = { 'specimen' => { 'reference' => 'Specimen/456' } }
        contained = [{ 'resourceType' => 'Specimen', 'id' => '123', 'type' => { 'text' => 'Blood' } }]

        result = adapter.send(:get_sample_tested, record, contained)

        expect(result).to eq('')
      end
    end

    context 'when specimen object exists but type is missing' do
      it 'returns an empty string' do
        record = { 'specimen' => { 'reference' => 'Specimen/123' } }
        contained = [{ 'resourceType' => 'Specimen', 'id' => '123' }]

        result = adapter.send(:get_sample_tested, record, contained)

        expect(result).to eq('')
      end
    end

    context 'when specimen reference is found with valid type' do
      it 'returns the specimen type text' do
        record = { 'specimen' => { 'reference' => 'Specimen/123' } }
        contained = [{ 'resourceType' => 'Specimen', 'id' => '123', 'type' => { 'text' => 'Blood' } }]

        result = adapter.send(:get_sample_tested, record, contained)

        expect(result).to eq('Blood')
      end
    end

    context 'when multiple specimen references are provided' do
      it 'returns all specimen types joined by comma' do
        record = {
          'specimen' => [
            { 'reference' => 'Specimen/123' },
            { 'reference' => 'Specimen/456' }
          ]
        }
        contained = [
          { 'resourceType' => 'Specimen', 'id' => '123', 'type' => { 'text' => 'Blood' } },
          { 'resourceType' => 'Specimen', 'id' => '456', 'type' => { 'text' => 'Urine' } }
        ]

        result = adapter.send(:get_sample_tested, record, contained)

        expect(result).to eq('Blood, Urine')
      end
    end

    context 'when some specimen references are not found in contained array' do
      it 'returns only the found specimens' do
        record = {
          'specimen' => [
            { 'reference' => 'Specimen/123' },
            { 'reference' => 'Specimen/999' }
          ]
        }
        contained = [
          { 'resourceType' => 'Specimen', 'id' => '123', 'type' => { 'text' => 'Blood' } }
        ]

        result = adapter.send(:get_sample_tested, record, contained)

        expect(result).to eq('Blood')
      end
    end
  end

  describe '#get_observations' do
    context 'when contained is nil' do
      it 'returns an empty array' do
        record = { 'resource' => { 'contained' => nil } }

        result = adapter.send(:get_observations, record)

        expect(result).to eq([])
      end
    end

    context 'with reference ranges' do
      it 'returns observations with a single reference range' do
        record = {
          'resource' => {
            'contained' => [
              {
                'resourceType' => 'Observation',
                'code' => { 'text' => 'Glucose' },
                'valueQuantity' => { 'value' => 100, 'unit' => 'mg/dL' },
                'referenceRange' => [
                  { 'text' => '70-110 mg/dL' }
                ],
                'status' => 'final',
                'note' => [{ 'text' => 'Normal' }]
              }
            ]
          }
        }
        result = adapter.send(:get_observations, record)
        expect(result.size).to eq(1)
        expect(result.first.reference_range).to eq('70-110 mg/dL')
      end

      it 'returns observations with multiple reference ranges joined' do
        record = {
          'resource' => {
            'contained' => [
              {
                'resourceType' => 'Observation',
                'code' => { 'text' => 'Calcium' },
                'valueQuantity' => { 'value' => 9.5, 'unit' => 'mg/dL' },
                'referenceRange' => [
                  { 'text' => '8.5-10.5 mg/dL' },
                  { 'text' => 'Lab-specific: 9-11 mg/dL' }
                ],
                'status' => 'final',
                'note' => [{ 'text' => 'Within range' }]
              }
            ]
          }
        }
        result = adapter.send(:get_observations, record)
        expect(result.size).to eq(1)
        expect(result.first.reference_range).to eq('8.5-10.5 mg/dL, Lab-specific: 9-11 mg/dL')
      end

      it 'returns observations with low/high values in reference range' do
        record = {
          'resource' => {
            'contained' => [
              {
                'resourceType' => 'Observation',
                'code' => { 'text' => 'TSH' },
                'valueQuantity' => { 'value' => 1.8, 'unit' => 'mIU/L' },
                'referenceRange' => [
                  {
                    'low' => {
                      'value' => 0.7,
                      'unit' => 'mIU/L'
                    },
                    'high' => {
                      'value' => 4.5,
                      'unit' => 'mIU/L'
                    },
                    'type' => {
                      'coding' => [
                        {
                          'system' => 'http://terminology.hl7.org/CodeSystem/referencerange-meaning',
                          'code' => 'normal',
                          'display' => 'Normal Range'
                        }
                      ],
                      'text' => 'Normal Range'
                    }
                  }
                ],
                'status' => 'final',
                'note' => [{ 'text' => 'Within normal limits' }]
              }
            ]
          }
        }
        result = adapter.send(:get_observations, record)
        expect(result.size).to eq(1)
        expect(result.first.reference_range).to eq('Normal Range: 0.7 - 4.5 mIU/L')
      end

      it 'returns observations with multiple low/high reference ranges joined' do
        record = {
          'resource' => {
            'contained' => [
              {
                'resourceType' => 'Observation',
                'code' => { 'text' => 'Comprehensive Metabolic Panel' },
                'valueQuantity' => { 'value' => 1.8, 'unit' => 'mIU/L' },
                'referenceRange' => [
                  {
                    'low' => {
                      'value' => 0.7,
                      'unit' => 'mIU/L'
                    },
                    'high' => {
                      'value' => 4.5,
                      'unit' => 'mIU/L'
                    },
                    'type' => {
                      'coding' => [
                        {
                          'system' => 'http://terminology.hl7.org/CodeSystem/referencerange-meaning',
                          'code' => 'normal',
                          'display' => 'Normal Range'
                        }
                      ],
                      'text' => 'Normal Range'
                    }
                  },
                  {
                    'low' => {
                      'value' => 0.5,
                      'unit' => 'mIU/L'
                    },
                    'high' => {
                      'value' => 5.0,
                      'unit' => 'mIU/L'
                    },
                    'type' => {
                      'coding' => [
                        {
                          'system' => 'http://terminology.hl7.org/CodeSystem/referencerange-meaning',
                          'code' => 'treatment',
                          'display' => 'Treatment Range'
                        }
                      ],
                      'text' => 'Treatment Range'
                    }
                  }
                ],
                'status' => 'final',
                'note' => [{ 'text' => 'Multiple reference ranges' }]
              }
            ]
          }
        }
        result = adapter.send(:get_observations, record)
        expect(result.size).to eq(1)
        expect(result.first.reference_range).to eq(
          'Normal Range: 0.7 - 4.5 mIU/L, ' \
          'Treatment Range: 0.5 - 5.0 mIU/L'
        )
      end

      it 'returns empty string for reference range if not present' do
        record = {
          'resource' => {
            'contained' => [
              {
                'resourceType' => 'Observation',
                'code' => { 'text' => 'Sodium' },
                'valueQuantity' => { 'value' => 140, 'unit' => 'mmol/L' },
                'status' => 'final',
                'note' => [{ 'text' => 'Normal' }]
              }
            ]
          }
        }
        result = adapter.send(:get_observations, record)
        expect(result.size).to eq(1)
        expect(result.first.reference_range).to eq('')
      end

      it 'returns observations with only low value in reference range' do
        record = {
          'resource' => {
            'contained' => [
              {
                'resourceType' => 'Observation',
                'code' => { 'text' => 'Oxygen Saturation' },
                'valueQuantity' => { 'value' => 96, 'unit' => '%' },
                'referenceRange' => [
                  {
                    'low' => {
                      'value' => 94,
                      'unit' => '%'
                    },
                    'type' => {
                      'coding' => [
                        {
                          'system' => 'http://terminology.hl7.org/CodeSystem/referencerange-meaning',
                          'code' => 'normal',
                          'display' => 'Normal Range'
                        }
                      ],
                      'text' => 'Normal Range'
                    }
                  }
                ],
                'status' => 'final',
                'note' => [{ 'text' => 'Above minimum threshold' }]
              }
            ]
          }
        }
        result = adapter.send(:get_observations, record)
        expect(result.size).to eq(1)
        expect(result.first.reference_range).to eq('Normal Range: >= 94 %')
      end

      it 'returns observations with only high value in reference range' do
        record = {
          'resource' => {
            'contained' => [
              {
                'resourceType' => 'Observation',
                'code' => { 'text' => 'Blood Glucose' },
                'valueQuantity' => { 'value' => 105, 'unit' => 'mg/dL' },
                'referenceRange' => [
                  {
                    'high' => {
                      'value' => 120,
                      'unit' => 'mg/dL'
                    },
                    'type' => {
                      'coding' => [
                        {
                          'system' => 'http://terminology.hl7.org/CodeSystem/referencerange-meaning',
                          'code' => 'normal',
                          'display' => 'Normal Range'
                        }
                      ],
                      'text' => 'Normal Range'
                    }
                  }
                ],
                'status' => 'final',
                'note' => [{ 'text' => 'Below maximum threshold' }]
              }
            ]
          }
        }
        result = adapter.send(:get_observations, record)
        expect(result.size).to eq(1)
        expect(result.first.reference_range).to eq('Normal Range: <= 120 mg/dL')
      end

      it 'handles mixed reference range formats correctly' do
        record = {
          'resource' => {
            'contained' => [
              {
                'resourceType' => 'Observation',
                'code' => { 'text' => 'Mixed Format Test' },
                'valueQuantity' => { 'value' => 5, 'unit' => 'units' },
                'referenceRange' => [
                  { 'text' => 'YELLOW' },
                  {
                    'high' => { 'value' => 10 }
                  },
                  {
                    'low' => { 'value' => 1 }
                  },
                  {
                    'low' => { 'value' => 2 }
                  },
                  {
                    'high' => { 'value' => 8 }
                  }
                ],
                'status' => 'final'
              }
            ]
          }
        }
        result = adapter.send(:get_observations, record)
        expect(result.size).to eq(1)
        expect(result.first.reference_range).to eq('YELLOW, <= 10, >= 1, >= 2, <= 8')
      end
    end
  end

  describe '#get_code' do
    context 'when category is nil' do
      it 'returns nil' do
        record = { 'resource' => { 'category' => nil } }

        result = adapter.send(:get_code, record)

        expect(result).to be_nil
      end
    end

    context 'when category is empty' do
      it 'returns nil' do
        record = { 'resource' => { 'category' => [] } }

        result = adapter.send(:get_code, record)

        expect(result).to be_nil
      end
    end
  end

  describe '#parse_single_record' do
    context 'when record is nil' do
      it 'returns nil' do
        result = adapter.send(:parse_single_record, nil)

        expect(result).to be_nil
      end
    end

    context 'when resource is nil' do
      it 'returns nil' do
        record = {}

        result = adapter.send(:parse_single_record, record)

        expect(result).to be_nil
      end
    end

    context 'when status is final and missing data' do
      let(:base_record) do
        {
          'resource' => {
            'id' => 'test-123',
            'resourceType' => 'DiagnosticReport',
            'status' => 'final',
            'category' => [{ 'coding' => [{ 'code' => 'CH' }] }],
            'code' => { 'text' => 'Test' },
            'contained' => []
          }
        }
      end

      it 'logs warning when status is final and has no encoded data' do
        record = base_record.deep_dup
        record['resource']['contained'] = [
          {
            'resourceType' => 'Observation',
            'code' => { 'text' => 'Test Observation' },
            'status' => 'final'
          }
        ]
        record['resource']['effectiveDateTime'] = '2024-06-01T00:00:00Z'

        expect(Rails.logger).to receive(:warn).with(
          "DiagnosticReport test-123 has status 'final' but is missing encoded data"
        )

        result = adapter.send(:parse_single_record, record)
        expect(result).not_to be_nil
      end

      it 'logs warning when status is final and has no observations' do
        record = base_record.deep_dup
        record['resource']['presentedForm'] = [{ 'data' => 'encoded-data-here' }]
        record['resource']['effectiveDateTime'] = '2024-06-01T00:00:00Z'

        expect(Rails.logger).to receive(:warn).with(
          "DiagnosticReport test-123 has status 'final' but is missing observations"
        )

        result = adapter.send(:parse_single_record, record)
        expect(result).not_to be_nil
      end

      it 'logs warning when status is final and has neither encoded data nor observations' do
        record = base_record.deep_dup
        record['resource']['effectiveDateTime'] = '2024-06-01T00:00:00Z'

        expect(Rails.logger).to receive(:warn).with(
          "DiagnosticReport test-123 has status 'final' but is missing both encoded data and observations"
        )

        result = adapter.send(:parse_single_record, record)
        expect(result).not_to be_nil
      end

      it 'does not log when status is final but has both encoded data and observations' do
        record = base_record.deep_dup
        record['resource']['presentedForm'] = [{ 'data' => 'encoded-data-here' }]
        record['resource']['contained'] = [
          {
            'resourceType' => 'Observation',
            'code' => { 'text' => 'Test Observation' },
            'status' => 'final'
          }
        ]
        record['resource']['effectiveDateTime'] = '2024-06-01T00:00:00Z'

        expect(Rails.logger).not_to receive(:warn)

        result = adapter.send(:parse_single_record, record)
        expect(result).not_to be_nil
      end

      it 'does not log when status is not final even if missing data' do
        record = base_record.deep_dup
        record['resource']['status'] = 'preliminary'
        record['resource']['effectiveDateTime'] = '2024-06-01T00:00:00Z'

        expect(Rails.logger).not_to receive(:warn)

        result = adapter.send(:parse_single_record, record)
        expect(result).not_to be_nil
      end

      it 'does not log when status is nil even if missing data' do
        record = base_record.deep_dup
        record['resource']['status'] = nil
        record['resource']['effectiveDateTime'] = '2024-06-01T00:00:00Z'

        expect(Rails.logger).not_to receive(:warn)

        result = adapter.send(:parse_single_record, record)
        expect(result).not_to be_nil
      end
    end

    context 'when missing effective date information' do
      let(:base_record) do
        {
          'resource' => {
            'id' => 'test-456',
            'resourceType' => 'DiagnosticReport',
            'status' => 'final',
            'category' => [{ 'coding' => [{ 'code' => 'CH' }] }],
            'code' => { 'text' => 'Test' },
            'presentedForm' => [{ 'data' => 'encoded-data' }],
            'contained' => [
              {
                'resourceType' => 'Observation',
                'code' => { 'text' => 'Test Observation' },
                'status' => 'final'
              }
            ]
          }
        }
      end

      it 'logs warning when no effectiveDateTime and no effectivePeriod' do
        record = base_record.deep_dup

        expect(Rails.logger).to receive(:warn).with(
          'DiagnosticReport test-456 is missing effectiveDateTime and effectivePeriod start date'
        )

        result = adapter.send(:parse_single_record, record)
        expect(result).not_to be_nil
      end

      it 'logs warning when effectivePeriod exists but has no start date' do
        record = base_record.deep_dup
        record['resource']['effectivePeriod'] = { 'end' => '2024-06-01T00:00:00Z' }

        expect(Rails.logger).to receive(:warn).with(
          'DiagnosticReport test-456 is missing effectiveDateTime and effectivePeriod start date'
        )

        result = adapter.send(:parse_single_record, record)
        expect(result).not_to be_nil
      end

      it 'does not log when effectiveDateTime is present' do
        record = base_record.deep_dup
        record['resource']['effectiveDateTime'] = '2024-06-01T00:00:00Z'

        expect(Rails.logger).not_to receive(:warn).with(
          /missing effectiveDateTime/
        )

        result = adapter.send(:parse_single_record, record)
        expect(result).not_to be_nil
      end

      it 'does not log when effectivePeriod has a start date' do
        record = base_record.deep_dup
        record['resource']['effectivePeriod'] = {
          'start' => '2024-06-01T00:00:00Z',
          'end' => '2024-06-02T00:00:00Z'
        }

        expect(Rails.logger).not_to receive(:warn).with(
          /missing effectiveDateTime/
        )

        result = adapter.send(:parse_single_record, record)
        expect(result).not_to be_nil
      end
    end
  end

  describe '#parse_labs' do
    context 'when records is nil' do
      it 'returns an empty array' do
        result = adapter.send(:parse_labs, nil)

        expect(result).to eq([])
      end
    end

    context 'when records is empty' do
      it 'returns an empty array' do
        result = adapter.send(:parse_labs, [])

        expect(result).to eq([])
      end
    end
  end
end
