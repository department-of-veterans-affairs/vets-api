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

  describe 'TEST_CODE_DISPLAY_MAP' do
    let(:base_record) do
      {
        'resource' => {
          'resourceType' => 'DiagnosticReport',
          'id' => 'test-display-map',
          'status' => 'final',
          'code' => { 'text' => 'Test Report' },
          'effectiveDateTime' => '2025-01-01T00:00:00.000Z',
          'presentedForm' => [{ 'contentType' => 'text/plain', 'data' => 'test_data' }]
        }
      }
    end

    context 'with known test codes' do
      it 'maps CH to "Chemistry and hematology"' do
        record = base_record.deep_dup
        record['resource']['category'] = [{ 'coding' => [{ 'code' => 'CH' }] }]

        result = adapter.send(:parse_single_record, record)

        expect(result.test_code).to eq('CH')
        expect(result.test_code_display).to eq('Chemistry and hematology')
      end

      it 'maps MI to "Microbiology"' do
        record = base_record.deep_dup
        record['resource']['category'] = [{ 'coding' => [{ 'code' => 'MI' }] }]

        result = adapter.send(:parse_single_record, record)

        expect(result.test_code).to eq('MI')
        expect(result.test_code_display).to eq('Microbiology')
      end

      it 'maps SP to "Surgical Pathology"' do
        record = base_record.deep_dup
        record['resource']['category'] = [{ 'coding' => [{ 'code' => 'SP' }] }]

        result = adapter.send(:parse_single_record, record)

        expect(result.test_code).to eq('SP')
        expect(result.test_code_display).to eq('Surgical Pathology')
      end

      it 'maps CY to "Cytology"' do
        record = base_record.deep_dup
        record['resource']['category'] = [{ 'coding' => [{ 'code' => 'CY' }] }]

        result = adapter.send(:parse_single_record, record)

        expect(result.test_code).to eq('CY')
        expect(result.test_code_display).to eq('Cytology')
      end

      it 'maps EM to "Electron Microscopy"' do
        record = base_record.deep_dup
        record['resource']['category'] = [{ 'coding' => [{ 'code' => 'EM' }] }]

        result = adapter.send(:parse_single_record, record)

        expect(result.test_code).to eq('EM')
        expect(result.test_code_display).to eq('Electron Microscopy')
      end
    end

    context 'with unknown test codes' do
      it 'falls back to the raw code for unknown codes' do
        record = base_record.deep_dup
        record['resource']['category'] = [{ 'coding' => [{ 'code' => 'UNKNOWN' }] }]

        result = adapter.send(:parse_single_record, record)

        expect(result.test_code).to eq('UNKNOWN')
        expect(result.test_code_display).to eq('UNKNOWN')
      end

      it 'falls back to the raw code for LP29708-2 (Cardiology)' do
        record = base_record.deep_dup
        record['resource']['category'] = [{ 'coding' => [{ 'code' => 'LP29708-2' }] }]

        result = adapter.send(:parse_single_record, record)

        expect(result.test_code).to eq('LP29708-2')
        expect(result.test_code_display).to eq('LP29708-2')
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

      it 'does not log when status is final and has encoded data but no observations' do
        record = base_record.deep_dup
        record['resource']['presentedForm'] = [{ 'contentType' => 'text/plain', 'data' => 'encoded-data-here' }]
        record['resource']['effectiveDateTime'] = '2024-06-01T00:00:00Z'

        expect(Rails.logger).not_to receive(:warn)

        result = adapter.send(:parse_single_record, record)
        expect(result).not_to be_nil
      end

      it 'does not log when status is final and has observations but no encoded data' do
        record = base_record.deep_dup
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

      it 'returns nil when status is final and has neither encoded data nor valid observations' do
        record = base_record.deep_dup
        record['resource']['effectiveDateTime'] = '2024-06-01T00:00:00Z'
        record['resource']['subject'] = { 'reference' => 'Patient/123456789' }

        # Should log warning before returning nil
        expect(Rails.logger).to receive(:warn).with(
          "DiagnosticReport test-123 has status 'final' but is missing both encoded data and observations " \
          '(Patient: 6789)',
          { service: 'unified_health_data' }
        )
        allow(Rails.logger).to receive(:info)
        allow(StatsD).to receive(:increment)

        result = adapter.send(:parse_single_record, record)
        expect(result).to be_nil
      end

      it 'does not log when status is final but has both encoded data and observations' do
        record = base_record.deep_dup
        record['resource']['presentedForm'] = [{ 'contentType' => 'text/plain', 'data' => 'encoded-data-here' }]
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

      it 'filters out records with status not final even if they have data' do
        record = base_record.deep_dup
        record['resource']['status'] = 'preliminary'
        record['resource']['effectiveDateTime'] = '2024-06-01T00:00:00Z'
        record['resource']['presentedForm'] = [{ 'contentType' => 'text/plain', 'data' => 'encoded-data-here' }]

        expect(Rails.logger).not_to receive(:warn).with(
          /has status 'final' but is missing/
        )

        result = adapter.send(:parse_single_record, record)
        expect(result).to be_nil
      end

      it 'filters out records with nil status even if they have data' do
        record = base_record.deep_dup
        record['resource']['status'] = nil
        record['resource']['effectiveDateTime'] = '2024-06-01T00:00:00Z'
        record['resource']['presentedForm'] = [{ 'contentType' => 'text/plain', 'data' => 'encoded-data-here' }]

        expect(Rails.logger).not_to receive(:warn).with(
          /has status 'final' but is missing/
        )

        result = adapter.send(:parse_single_record, record)
        expect(result).to be_nil
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
          'DiagnosticReport test-456 is missing effectiveDateTime and effectivePeriod',
          { service: 'unified_health_data' }
        )

        result = adapter.send(:parse_single_record, record)
        expect(result).not_to be_nil
      end

      it 'logs warning when effectivePeriod exists but has no start date' do
        record = base_record.deep_dup
        record['resource']['effectivePeriod'] = { 'end' => '2024-06-01T00:00:00Z' }

        expect(Rails.logger).to receive(:warn).with(
          'DiagnosticReport test-456 is missing effectivePeriod.start',
          { service: 'unified_health_data' }
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
          'start' => '2024-06-01T00:00:00Z'
        }

        expect(Rails.logger).not_to receive(:warn).with(
          /missing effectiveDateTime/
        )

        result = adapter.send(:parse_single_record, record)
        expect(result).not_to be_nil
      end
    end
  end

  describe '#get_encoded_data' do
    context 'when presentedForm has data field with text/plain contentType' do
      it 'returns the data' do
        resource = { 'presentedForm' => [{ 'contentType' => 'text/plain', 'data' => 'encoded_content' }] }

        result = adapter.send(:get_encoded_data, resource)

        expect(result).to eq('encoded_content')
      end
    end

    context 'when presentedForm has multiple items' do
      it 'returns data from text/plain item' do
        resource = {
          'presentedForm' => [
            { 'contentType' => 'application/pdf', 'data' => 'pdf_content' },
            { 'contentType' => 'text/plain', 'data' => 'plain_text_content' },
            { 'contentType' => 'text/html', 'data' => 'html_content' }
          ]
        }

        result = adapter.send(:get_encoded_data, resource)

        expect(result).to eq('plain_text_content')
      end
    end

    context 'when presentedForm has no text/plain item' do
      it 'returns empty string' do
        resource = {
          'presentedForm' => [
            { 'contentType' => 'application/pdf', 'data' => 'pdf_content' }
          ]
        }

        result = adapter.send(:get_encoded_data, resource)

        expect(result).to eq('')
      end
    end

    context 'when presentedForm has data-absent-reason extension' do
      it 'returns empty string' do
        resource = {
          'presentedForm' => [{
            'extension' => [{
              'valueCode' => 'unsupported',
              'url' => 'http://hl7.org/fhir/StructureDefinition/data-absent-reason'
            }]
          }]
        }

        result = adapter.send(:get_encoded_data, resource)

        expect(result).to eq('')
      end
    end

    context 'when presentedForm is nil' do
      it 'returns empty string' do
        resource = { 'presentedForm' => nil }

        result = adapter.send(:get_encoded_data, resource)

        expect(result).to eq('')
      end
    end

    context 'when presentedForm is empty array' do
      it 'returns empty string' do
        resource = { 'presentedForm' => [] }

        result = adapter.send(:get_encoded_data, resource)

        expect(result).to eq('')
      end
    end
  end

  describe '#get_date_completed' do
    context 'when resource has effectiveDateTime' do
      it 'returns effectiveDateTime' do
        resource = { 'effectiveDateTime' => '2025-06-24T15:21:00.000Z' }

        result = adapter.send(:get_date_completed, resource)

        expect(result).to eq('2025-06-24T15:21:00.000Z')
      end
    end

    context 'when resource has effectivePeriod with start' do
      it 'returns effectivePeriod start date' do
        resource = {
          'effectivePeriod' => {
            'start' => '2025-06-24T15:21:00.000Z',
            'end' => '2025-06-24T15:21:00.000Z'
          }
        }

        result = adapter.send(:get_date_completed, resource)

        expect(result).to eq('2025-06-24T15:21:00.000Z')
      end
    end

    context 'when resource has neither effectiveDateTime nor effectivePeriod' do
      it 'returns nil' do
        resource = {}

        result = adapter.send(:get_date_completed, resource)

        expect(result).to be_nil
      end
    end

    context 'when effectivePeriod exists but has no start' do
      it 'returns nil' do
        resource = { 'effectivePeriod' => { 'end' => '2025-06-24T15:21:00.000Z' } }

        result = adapter.send(:get_date_completed, resource)

        expect(result).to be_nil
      end
    end
  end

  describe '#parse_single_record with Oracle Health FHIR format' do
    context 'with ECG diagnostic report (no contained resources, effectivePeriod, presentedForm extension)' do
      it 'processes the record successfully with encoded data' do
        record = {
          'resource' => {
            'resourceType' => 'DiagnosticReport',
            'id' => '15249582244',
            'status' => 'final',
            'category' => [{
              'coding' => [{
                'system' => 'http://loinc.org',
                'code' => 'LP29708-2',
                'userSelected' => false
              }],
              'text' => 'Cardiology'
            }],
            'code' => {
              'coding' => [{
                'system' => 'https://fhir.cerner.com/d45741b3-8335-463d-ab16-8c5f0bcf78ed/codeSet/72',
                'code' => '344361949',
                'display' => '12 Lead ECG/EKG',
                'userSelected' => true
              }],
              'text' => '12 Lead ECG/EKG'
            },
            'effectivePeriod' => {
              'start' => '2025-06-24T15:21:00.000Z',
              'end' => '2025-06-24T15:21:00.000Z'
            },
            'presentedForm' => [{
              'contentType' => 'text/plain',
              'data' => 'RUNHIFJlcG9ydCBEYXRh'
            }]
          }
        }

        result = adapter.send(:parse_single_record, record)

        expect(result).not_to be_nil
        expect(result.id).to eq('15249582244')
        expect(result.type).to eq('DiagnosticReport')
        expect(result.display).to eq('12 Lead ECG/EKG')
        expect(result.test_code).to eq('LP29708-2')
        expect(result.date_completed).to eq('2025-06-24T15:21:00.000Z')
        expect(result.encoded_data).to eq('RUNHIFJlcG9ydCBEYXRh')
        expect(result.observations).to eq([])
        expect(result.sample_tested).to eq('')
        expect(result.body_site).to eq('')
        expect(result.status).to eq('final')
        expect(result.location).to be_nil
        expect(result.ordered_by).to be_nil
      end

      it 'filters out record with no valid data (only data-absent-reason extension)' do
        record = {
          'resource' => {
            'resourceType' => 'DiagnosticReport',
            'id' => '15249582244',
            'status' => 'final',
            'category' => [{
              'coding' => [{
                'system' => 'http://loinc.org',
                'code' => 'LP29708-2',
                'userSelected' => false
              }],
              'text' => 'Cardiology'
            }],
            'code' => {
              'coding' => [{
                'system' => 'https://fhir.cerner.com/d45741b3-8335-463d-ab16-8c5f0bcf78ed/codeSet/72',
                'code' => '344361949',
                'display' => '12 Lead ECG/EKG',
                'userSelected' => true
              }],
              'text' => '12 Lead ECG/EKG'
            },
            'effectivePeriod' => {
              'start' => '2025-06-24T15:21:00.000Z',
              'end' => '2025-06-24T15:21:00.000Z'
            },
            'presentedForm' => [{
              'extension' => [{
                'valueCode' => 'unsupported',
                'url' => 'http://hl7.org/fhir/StructureDefinition/data-absent-reason'
              }]
            }]
          }
        }

        result = adapter.send(:parse_single_record, record)

        expect(result).to be_nil
      end
    end
  end

  describe 'status field extraction' do
    context 'with different status values' do
      it 'extracts final status correctly' do
        record = {
          'resource' => {
            'resourceType' => 'DiagnosticReport',
            'id' => '123',
            'status' => 'final',
            'category' => [{ 'coding' => [{ 'code' => 'CH' }] }],
            'code' => { 'text' => 'Test Report' },
            'effectiveDateTime' => '2025-01-01T00:00:00.000Z',
            'presentedForm' => [{ 'contentType' => 'text/plain', 'data' => 'test_data' }]
          }
        }

        result = adapter.send(:parse_single_record, record)

        expect(result).not_to be_nil
        expect(result.status).to eq('final')
      end

      it 'filters out preliminary status' do
        record = {
          'resource' => {
            'resourceType' => 'DiagnosticReport',
            'id' => '456',
            'status' => 'preliminary',
            'category' => [{ 'coding' => [{ 'code' => 'SP' }] }],
            'code' => { 'text' => 'Lab Report' },
            'effectiveDateTime' => '2025-01-01T00:00:00.000Z',
            'presentedForm' => [{ 'contentType' => 'text/plain', 'data' => 'test_data' }]
          }
        }

        result = adapter.send(:parse_single_record, record)

        expect(result).to be_nil
      end
    end

    context 'when status is missing' do
      it 'filters out records with nil status' do
        record = {
          'resource' => {
            'resourceType' => 'DiagnosticReport',
            'id' => '789',
            'category' => [{ 'coding' => [{ 'code' => 'MB' }] }],
            'code' => { 'text' => 'Missing Status Report' },
            'effectiveDateTime' => '2025-01-01T00:00:00.000Z',
            'presentedForm' => [{ 'contentType' => 'text/plain', 'data' => 'test_data' }]
          }
        }

        result = adapter.send(:parse_single_record, record)

        expect(result).to be_nil
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

  describe 'status filtering' do
    let(:base_record) do
      {
        'resource' => {
          'resourceType' => 'DiagnosticReport',
          'id' => 'test-123',
          'category' => [{ 'coding' => [{ 'code' => 'CH' }] }],
          'code' => { 'text' => 'Test Report' },
          'effectiveDateTime' => '2025-01-01T00:00:00.000Z',
          'presentedForm' => [{ 'contentType' => 'text/plain', 'data' => 'test_data' }]
        }
      }
    end

    describe '#parse_single_record' do
      context 'with allowed DiagnosticReport statuses' do
        it 'processes records with status "final"' do
          record = base_record.deep_dup
          record['resource']['status'] = 'final'

          result = adapter.send(:parse_single_record, record)

          expect(result).not_to be_nil
          expect(result.status).to eq('final')
        end

        it 'processes records with status "amended"' do
          record = base_record.deep_dup
          record['resource']['status'] = 'amended'

          result = adapter.send(:parse_single_record, record)

          expect(result).not_to be_nil
          expect(result.status).to eq('amended')
        end

        it 'processes records with status "corrected"' do
          record = base_record.deep_dup
          record['resource']['status'] = 'corrected'

          result = adapter.send(:parse_single_record, record)

          expect(result).not_to be_nil
          expect(result.status).to eq('corrected')
        end

        it 'processes records with status "appended"' do
          record = base_record.deep_dup
          record['resource']['status'] = 'appended'

          result = adapter.send(:parse_single_record, record)

          expect(result).not_to be_nil
          expect(result.status).to eq('appended')
        end
      end

      context 'with disallowed DiagnosticReport statuses' do
        it 'filters out records with status "preliminary"' do
          record = base_record.deep_dup
          record['resource']['status'] = 'preliminary'

          result = adapter.send(:parse_single_record, record)

          expect(result).to be_nil
        end

        it 'filters out records with status "partial"' do
          record = base_record.deep_dup
          record['resource']['status'] = 'partial'

          result = adapter.send(:parse_single_record, record)

          expect(result).to be_nil
        end

        it 'filters out records with status "cancelled"' do
          record = base_record.deep_dup
          record['resource']['status'] = 'cancelled'

          result = adapter.send(:parse_single_record, record)

          expect(result).to be_nil
        end

        it 'filters out records with status "entered-in-error"' do
          record = base_record.deep_dup
          record['resource']['status'] = 'entered-in-error'

          result = adapter.send(:parse_single_record, record)

          expect(result).to be_nil
        end

        it 'filters out records with status "unknown"' do
          record = base_record.deep_dup
          record['resource']['status'] = 'unknown'

          result = adapter.send(:parse_single_record, record)

          expect(result).to be_nil
        end

        it 'filters out records with nil status' do
          record = base_record.deep_dup
          record['resource']['status'] = nil

          result = adapter.send(:parse_single_record, record)

          expect(result).to be_nil
        end
      end

      context 'logging and metrics for filtered DiagnosticReports' do
        before do
          allow(StatsD).to receive(:increment)
          allow(Rails.logger).to receive(:info)
        end

        it 'logs and tracks when DiagnosticReport is filtered due to disallowed status' do
          record = base_record.deep_dup
          record['resource']['status'] = 'preliminary'

          expect(Rails.logger).to receive(:info).with(
            /Filtered DiagnosticReport: id=test-123, status=preliminary, reason=disallowed_status/,
            hash_including(service: 'unified_health_data', filtering: true)
          )
          expect(StatsD).to receive(:increment).with(
            'unified_health_data.lab_or_test.filtered_diagnostic_report',
            tags: ['reason:disallowed_status']
          )

          adapter.send(:parse_single_record, record)
        end

        it 'logs and tracks when DiagnosticReport is filtered due to no valid data' do
          record = base_record.deep_dup
          record['resource']['status'] = 'final'
          record['resource']['presentedForm'] = []
          record['resource']['contained'] = []

          expect(Rails.logger).to receive(:info).with(
            /Filtered DiagnosticReport: id=test-123, status=final, reason=no_valid_data/,
            hash_including(service: 'unified_health_data', filtering: true)
          )
          expect(StatsD).to receive(:increment).with(
            'unified_health_data.lab_or_test.filtered_diagnostic_report',
            tags: ['reason:no_valid_data']
          )

          adapter.send(:parse_single_record, record)
        end
      end
    end

    describe '#get_observations' do
      context 'with allowed Observation statuses' do
        it 'includes observations with status "final"' do
          record = {
            'resource' => {
              'contained' => [
                {
                  'resourceType' => 'Observation',
                  'code' => { 'text' => 'Glucose' },
                  'valueQuantity' => { 'value' => 100, 'unit' => 'mg/dL' },
                  'status' => 'final'
                }
              ]
            }
          }

          result = adapter.send(:get_observations, record)

          expect(result.size).to eq(1)
          expect(result.first.status).to eq('final')
        end

        it 'includes observations with status "amended"' do
          record = {
            'resource' => {
              'contained' => [
                {
                  'resourceType' => 'Observation',
                  'code' => { 'text' => 'Glucose' },
                  'valueQuantity' => { 'value' => 100, 'unit' => 'mg/dL' },
                  'status' => 'amended'
                }
              ]
            }
          }

          result = adapter.send(:get_observations, record)

          expect(result.size).to eq(1)
          expect(result.first.status).to eq('amended')
        end

        it 'includes observations with status "corrected"' do
          record = {
            'resource' => {
              'contained' => [
                {
                  'resourceType' => 'Observation',
                  'code' => { 'text' => 'Glucose' },
                  'valueQuantity' => { 'value' => 100, 'unit' => 'mg/dL' },
                  'status' => 'corrected'
                }
              ]
            }
          }

          result = adapter.send(:get_observations, record)

          expect(result.size).to eq(1)
          expect(result.first.status).to eq('corrected')
        end

        it 'includes observations with status "appended"' do
          record = {
            'resource' => {
              'contained' => [
                {
                  'resourceType' => 'Observation',
                  'code' => { 'text' => 'Glucose' },
                  'valueQuantity' => { 'value' => 100, 'unit' => 'mg/dL' },
                  'status' => 'appended'
                }
              ]
            }
          }

          result = adapter.send(:get_observations, record)

          expect(result.size).to eq(1)
          expect(result.first.status).to eq('appended')
        end
      end

      context 'with disallowed Observation statuses' do
        it 'filters out observations with status "preliminary"' do
          record = {
            'resource' => {
              'contained' => [
                {
                  'resourceType' => 'Observation',
                  'code' => { 'text' => 'Glucose' },
                  'valueQuantity' => { 'value' => 100, 'unit' => 'mg/dL' },
                  'status' => 'preliminary'
                }
              ]
            }
          }

          result = adapter.send(:get_observations, record)

          expect(result).to be_empty
        end

        it 'filters out observations with status "cancelled"' do
          record = {
            'resource' => {
              'contained' => [
                {
                  'resourceType' => 'Observation',
                  'code' => { 'text' => 'Glucose' },
                  'valueQuantity' => { 'value' => 100, 'unit' => 'mg/dL' },
                  'status' => 'cancelled'
                }
              ]
            }
          }

          result = adapter.send(:get_observations, record)

          expect(result).to be_empty
        end

        it 'filters out observations with nil status' do
          record = {
            'resource' => {
              'contained' => [
                {
                  'resourceType' => 'Observation',
                  'code' => { 'text' => 'Glucose' },
                  'valueQuantity' => { 'value' => 100, 'unit' => 'mg/dL' },
                  'status' => nil
                }
              ]
            }
          }

          result = adapter.send(:get_observations, record)

          expect(result).to be_empty
        end
      end

      context 'with mixed Observation statuses' do
        it 'includes only observations with allowed status' do
          record = {
            'resource' => {
              'contained' => [
                {
                  'resourceType' => 'Observation',
                  'code' => { 'text' => 'Glucose' },
                  'valueQuantity' => { 'value' => 100, 'unit' => 'mg/dL' },
                  'status' => 'final'
                },
                {
                  'resourceType' => 'Observation',
                  'code' => { 'text' => 'Sodium' },
                  'valueQuantity' => { 'value' => 140, 'unit' => 'mmol/L' },
                  'status' => 'cancelled'
                },
                {
                  'resourceType' => 'Observation',
                  'code' => { 'text' => 'Potassium' },
                  'valueQuantity' => { 'value' => 4.0, 'unit' => 'mmol/L' },
                  'status' => 'amended'
                }
              ]
            }
          }

          result = adapter.send(:get_observations, record)

          expect(result.size).to eq(2)
          expect(result.map(&:test_code)).to contain_exactly('Glucose', 'Potassium')
          expect(result.map(&:status)).to contain_exactly('final', 'amended')
        end
      end

      context 'logging and metrics for filtered Observations' do
        before do
          allow(StatsD).to receive(:increment)
          allow(Rails.logger).to receive(:info)
        end

        it 'logs and tracks when Observations are filtered' do
          record = {
            'resource' => {
              'id' => 'diag-report-456',
              'contained' => [
                {
                  'resourceType' => 'Observation',
                  'code' => { 'text' => 'Valid Obs' },
                  'valueQuantity' => { 'value' => 100, 'unit' => 'mg/dL' },
                  'status' => 'final'
                },
                {
                  'resourceType' => 'Observation',
                  'code' => { 'text' => 'Invalid Obs' },
                  'valueQuantity' => { 'value' => 200, 'unit' => 'mg/dL' },
                  'status' => 'cancelled'
                }
              ]
            }
          }

          expect(Rails.logger).to receive(:info).with(
            %r{Filtered 1/2 Observations from DiagnosticReport diag-report-456},
            hash_including(service: 'unified_health_data', filtering: true)
          )
          expect(StatsD).to receive(:increment).with(
            'unified_health_data.lab_or_test.filtered_observations'
          )

          adapter.send(:get_observations, record)
        end

        it 'does not log when no Observations are filtered' do
          record = {
            'resource' => {
              'id' => 'diag-report-789',
              'contained' => [
                {
                  'resourceType' => 'Observation',
                  'code' => { 'text' => 'Valid Obs 1' },
                  'valueQuantity' => { 'value' => 100, 'unit' => 'mg/dL' },
                  'status' => 'final'
                },
                {
                  'resourceType' => 'Observation',
                  'code' => { 'text' => 'Valid Obs 2' },
                  'valueQuantity' => { 'value' => 200, 'unit' => 'mg/dL' },
                  'status' => 'amended'
                }
              ]
            }
          }

          expect(Rails.logger).not_to receive(:info).with(/Filtered.*Observations/, anything)
          expect(StatsD).not_to receive(:increment).with('unified_health_data.lab_or_test.filtered_observations')

          adapter.send(:get_observations, record)
        end
      end
    end

    describe '#parse_single_record with mixed observations' do
      context 'when DiagnosticReport has final status with mixed observation statuses' do
        it 'returns DiagnosticReport with only valid observations' do
          record = base_record.deep_dup
          record['resource']['status'] = 'final'
          record['resource']['contained'] = [
            {
              'resourceType' => 'Observation',
              'code' => { 'text' => 'Valid Obs 1' },
              'valueQuantity' => { 'value' => 100, 'unit' => 'mg/dL' },
              'status' => 'final'
            },
            {
              'resourceType' => 'Observation',
              'code' => { 'text' => 'Invalid Obs' },
              'valueQuantity' => { 'value' => 140, 'unit' => 'mmol/L' },
              'status' => 'cancelled'
            },
            {
              'resourceType' => 'Observation',
              'code' => { 'text' => 'Valid Obs 2' },
              'valueQuantity' => { 'value' => 4.0, 'unit' => 'mmol/L' },
              'status' => 'corrected'
            }
          ]

          result = adapter.send(:parse_single_record, record)

          expect(result).not_to be_nil
          expect(result.observations.size).to eq(2)
          expect(result.observations.map(&:test_code)).to contain_exactly('Valid Obs 1', 'Valid Obs 2')
        end

        it 'returns DiagnosticReport with encoded_data when all observations are invalid' do
          record = base_record.deep_dup
          record['resource']['status'] = 'final'
          record['resource']['presentedForm'] = [{ 'contentType' => 'text/plain', 'data' => 'encoded_data' }]
          record['resource']['contained'] = [
            {
              'resourceType' => 'Observation',
              'code' => { 'text' => 'Invalid Obs' },
              'valueQuantity' => { 'value' => 140, 'unit' => 'mmol/L' },
              'status' => 'cancelled'
            }
          ]

          result = adapter.send(:parse_single_record, record)

          expect(result).not_to be_nil
          expect(result.observations).to be_empty
          expect(result.encoded_data).to eq('encoded_data')
        end

        it 'returns nil when no encoded_data and all observations are invalid' do
          record = base_record.deep_dup
          record['resource']['status'] = 'final'
          record['resource']['presentedForm'] = []
          record['resource']['contained'] = [
            {
              'resourceType' => 'Observation',
              'code' => { 'text' => 'Invalid Obs' },
              'valueQuantity' => { 'value' => 140, 'unit' => 'mmol/L' },
              'status' => 'cancelled'
            }
          ]

          result = adapter.send(:parse_single_record, record)

          expect(result).to be_nil
        end
      end
    end

    describe '#parse_labs' do
      context 'with multiple records with mixed statuses' do
        it 'filters records and returns only those with allowed statuses' do
          records = [
            {
              'resource' => {
                'resourceType' => 'DiagnosticReport',
                'id' => '1',
                'status' => 'final',
                'category' => [{ 'coding' => [{ 'code' => 'CH' }] }],
                'code' => { 'text' => 'Test 1' },
                'effectiveDateTime' => '2025-01-01T00:00:00.000Z',
                'presentedForm' => [{ 'contentType' => 'text/plain', 'data' => 'data1' }]
              }
            },
            {
              'resource' => {
                'resourceType' => 'DiagnosticReport',
                'id' => '2',
                'status' => 'preliminary',
                'category' => [{ 'coding' => [{ 'code' => 'CH' }] }],
                'code' => { 'text' => 'Test 2' },
                'effectiveDateTime' => '2025-01-01T00:00:00.000Z',
                'presentedForm' => [{ 'contentType' => 'text/plain', 'data' => 'data2' }]
              }
            },
            {
              'resource' => {
                'resourceType' => 'DiagnosticReport',
                'id' => '3',
                'status' => 'amended',
                'category' => [{ 'coding' => [{ 'code' => 'CH' }] }],
                'code' => { 'text' => 'Test 3' },
                'effectiveDateTime' => '2025-01-01T00:00:00.000Z',
                'presentedForm' => [{ 'contentType' => 'text/plain', 'data' => 'data3' }]
              }
            },
            {
              'resource' => {
                'resourceType' => 'DiagnosticReport',
                'id' => '4',
                'status' => 'cancelled',
                'category' => [{ 'coding' => [{ 'code' => 'CH' }] }],
                'code' => { 'text' => 'Test 4' },
                'effectiveDateTime' => '2025-01-01T00:00:00.000Z',
                'presentedForm' => [{ 'contentType' => 'text/plain', 'data' => 'data4' }]
              }
            }
          ]

          result = adapter.send(:parse_labs, records)

          expect(result.size).to eq(2)
          expect(result.map(&:id)).to contain_exactly('1', '3')
          expect(result.map(&:status)).to contain_exactly('final', 'amended')
        end
      end
    end
  end
end
