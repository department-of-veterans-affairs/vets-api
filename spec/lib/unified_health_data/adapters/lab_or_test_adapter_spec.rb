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
    it 'returns the Organization name matching the performer reference' do
      record = { 'resource' => {
        'performer' => [{ 'reference' => 'Organization/org-456' }],
        'contained' => [
          { 'resourceType' => 'Organization', 'id' => 'org-123', 'name' => 'Wrong Lab' },
          { 'resourceType' => 'Organization', 'id' => 'org-456', 'name' => 'Correct Lab' }
        ]
      } }
      expect(adapter.send(:get_location, record)).to eq('Correct Lab')
    end

    it 'returns the Location name matching the performer reference' do
      record = { 'resource' => {
        'performer' => [{ 'reference' => 'Location/loc-789' }],
        'contained' => [
          { 'resourceType' => 'Location', 'id' => 'loc-789', 'name' => 'Primary Care Blue' }
        ]
      } }
      expect(adapter.send(:get_location, record)).to eq('Primary Care Blue')
    end

    it 'skips non-location performer references and matches Organization' do
      record = { 'resource' => {
        'performer' => [
          { 'reference' => 'Practitioner/prac-1' },
          { 'reference' => 'Organization/org-2' }
        ],
        'contained' => [
          { 'resourceType' => 'Practitioner', 'id' => 'prac-1', 'name' => [{ 'family' => 'Smith' }] },
          { 'resourceType' => 'Organization', 'id' => 'org-2', 'name' => 'Test Lab' }
        ]
      } }
      expect(adapter.send(:get_location, record)).to eq('Test Lab')
    end

    it 'falls back to first Organization when no performer references exist' do
      record = { 'resource' => {
        'contained' => [{ 'resourceType' => 'Organization', 'name' => 'Fallback Lab' }]
      } }
      expect(adapter.send(:get_location, record)).to eq('Fallback Lab')
    end

    it 'returns nil if no Organization or Location matches and no fallback exists' do
      record = { 'resource' => {
        'performer' => [{ 'reference' => 'Practitioner/prac-1' }],
        'contained' => [{ 'resourceType' => 'Practitioner', 'id' => 'prac-1' }]
      } }
      expect(adapter.send(:get_location, record)).to be_nil
    end

    it 'returns nil if contained is nil' do
      record = { 'resource' => {} }
      expect(adapter.send(:get_location, record)).to be_nil
    end

    it 'handles performer entries with nil reference gracefully' do
      record = { 'resource' => {
        'performer' => [{ 'reference' => nil }, { 'reference' => 'Organization/org-1' }],
        'contained' => [
          { 'resourceType' => 'Organization', 'id' => 'org-1', 'name' => 'Good Lab' }
        ]
      } }
      expect(adapter.send(:get_location, record)).to eq('Good Lab')
    end

    it 'falls back to first Organization when all performer references are nil' do
      record = { 'resource' => {
        'performer' => [{ 'reference' => nil }, { 'reference' => nil }],
        'contained' => [
          { 'resourceType' => 'Organization', 'id' => 'org-1', 'name' => 'Fallback Lab' }
        ]
      } }
      expect(adapter.send(:get_location, record)).to eq('Fallback Lab')
    end
  end

  describe '#get_ordered_by' do
    it 'returns practitioner full name matching the service request requester' do
      record = { 'resource' => { 'contained' => [
        { 'resourceType' => 'ServiceRequest', 'requester' => { 'reference' => 'Practitioner/abc-123' } },
        { 'resourceType' => 'Practitioner', 'id' => 'abc-123',
          'name' => [{ 'given' => ['A'], 'family' => 'B' }] },
        { 'resourceType' => 'Practitioner', 'id' => 'other-456',
          'name' => [{ 'given' => ['X'], 'family' => 'Y' }] }
      ] } }
      expect(adapter.send(:get_ordered_by, record)).to eq('A B')
    end

    it 'returns requester display when practitioner is not in contained' do
      record = { 'resource' => { 'contained' => [
        { 'resourceType' => 'ServiceRequest',
          'requester' => { 'reference' => 'Practitioner/ext-999', 'display' => 'Smith, Jane' } }
      ] } }
      expect(adapter.send(:get_ordered_by, record)).to eq('Smith, Jane')
    end

    it 'returns nil when no service request requester exists' do
      record = { 'resource' => { 'contained' => [
        { 'resourceType' => 'ServiceRequest' },
        { 'resourceType' => 'Practitioner', 'id' => 'abc-123',
          'name' => [{ 'given' => ['A'], 'family' => 'B' }] }
      ] } }
      expect(adapter.send(:get_ordered_by, record)).to be_nil
    end

    it 'returns nil if no service request' do
      record = { 'resource' => { 'contained' => [{ 'resourceType' => 'Practitioner', 'id' => 'abc',
                                                   'name' => [{ 'given' => ['A'], 'family' => 'B' }] }] } }
      expect(adapter.send(:get_ordered_by, record)).to be_nil
    end

    it 'returns nil if contained is nil' do
      record = { 'resource' => { 'contained' => nil } }
      expect(adapter.send(:get_ordered_by, record)).to be_nil
    end

    it 'returns requester display when requester reference is nil' do
      record = { 'resource' => { 'contained' => [
        { 'resourceType' => 'ServiceRequest',
          'requester' => { 'reference' => nil, 'display' => 'Doe, John' } }
      ] } }
      expect(adapter.send(:get_ordered_by, record)).to eq('Doe, John')
    end

    it 'returns nil when requester reference is nil and no display exists' do
      record = { 'resource' => { 'contained' => [
        { 'resourceType' => 'ServiceRequest',
          'requester' => { 'reference' => nil } },
        { 'resourceType' => 'Practitioner', 'id' => 'abc-123',
          'name' => [{ 'given' => ['A'], 'family' => 'B' }] }
      ] } }
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
        result = adapter.send(:get_body_site, resource, nil)
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

    context 'when ServiceRequest has bodySite with coding display' do
      it 'returns the coding display value' do
        contained = [{
          'resourceType' => 'ServiceRequest', 'id' => 'sr-1',
          'bodySite' => [{ 'coding' => [{ 'display' => 'SERUM' }] }]
        }]
        resource = { 'basedOn' => [{ 'reference' => 'ServiceRequest/sr-1' }] }
        expect(adapter.send(:get_body_site, resource, contained)).to eq('SERUM')
      end
    end

    context 'when ServiceRequest bodySite has text but no coding display' do
      it 'falls back to the text value' do
        contained = [{
          'resourceType' => 'ServiceRequest', 'id' => 'sr-1',
          'bodySite' => [{ 'coding' => [{ 'code' => '12345' }], 'text' => 'Left Arm' }]
        }]
        resource = { 'basedOn' => [{ 'reference' => 'ServiceRequest/sr-1' }] }
        expect(adapter.send(:get_body_site, resource, contained)).to eq('Left Arm')
      end
    end

    context 'when ServiceRequest bodySite has text but no coding array' do
      it 'returns the text value' do
        contained = [{
          'resourceType' => 'ServiceRequest', 'id' => 'sr-1',
          'bodySite' => [{ 'text' => 'Arm' }]
        }]
        resource = { 'basedOn' => [{ 'reference' => 'ServiceRequest/sr-1' }] }
        expect(adapter.send(:get_body_site, resource, contained)).to eq('Arm')
      end
    end

    context 'when ServiceRequest bodySite has multiple entries' do
      it 'joins them with commas' do
        contained = [{
          'resourceType' => 'ServiceRequest', 'id' => 'sr-1',
          'bodySite' => [
            { 'coding' => [{ 'display' => 'SERUM' }] },
            { 'text' => 'Arm' }
          ]
        }]
        resource = { 'basedOn' => [{ 'reference' => 'ServiceRequest/sr-1' }] }
        expect(adapter.send(:get_body_site, resource, contained)).to eq('SERUM, Arm')
      end
    end

    context 'when ServiceRequest has no bodySite' do
      it 'returns an empty string' do
        contained = [{ 'resourceType' => 'ServiceRequest', 'id' => 'sr-1' }]
        resource = { 'basedOn' => [{ 'reference' => 'ServiceRequest/sr-1' }] }
        expect(adapter.send(:get_body_site, resource, contained)).to eq('')
      end
    end

    context 'when basedOn reference does not match any ServiceRequest' do
      it 'returns an empty string' do
        contained = [{ 'resourceType' => 'ServiceRequest', 'id' => 'sr-other' }]
        resource = { 'basedOn' => [{ 'reference' => 'ServiceRequest/sr-missing' }] }
        expect(adapter.send(:get_body_site, resource, contained)).to eq('')
      end
    end

    context 'when basedOn entry has nil reference' do
      it 'returns an empty string' do
        contained = [{
          'resourceType' => 'ServiceRequest', 'id' => 'sr-1',
          'bodySite' => [{ 'coding' => [{ 'display' => 'SERUM' }] }]
        }]
        resource = { 'basedOn' => [{ 'reference' => nil }] }
        expect(adapter.send(:get_body_site, resource, contained)).to eq('')
      end
    end

    context 'when basedOn has mix of nil and valid references' do
      it 'returns body site from the valid reference only' do
        contained = [{
          'resourceType' => 'ServiceRequest', 'id' => 'sr-1',
          'bodySite' => [{ 'coding' => [{ 'display' => 'SERUM' }] }]
        }]
        resource = { 'basedOn' => [{ 'reference' => nil }, { 'reference' => 'ServiceRequest/sr-1' }] }
        expect(adapter.send(:get_body_site, resource, contained)).to eq('SERUM')
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

    context 'when specimen hash has nil reference' do
      it 'returns an empty string' do
        record = { 'specimen' => { 'reference' => nil } }
        contained = [{ 'resourceType' => 'Specimen', 'id' => '123', 'type' => { 'text' => 'Blood' } }]

        result = adapter.send(:get_sample_tested, record, contained)

        expect(result).to eq('')
      end
    end

    context 'when specimen array has entries with nil references' do
      it 'returns only specimens with valid references' do
        record = {
          'specimen' => [
            { 'reference' => nil },
            { 'reference' => 'Specimen/123' }
          ]
        }
        contained = [
          { 'resourceType' => 'Specimen', 'id' => '123', 'type' => { 'text' => 'Blood' } }
        ]

        result = adapter.send(:get_sample_tested, record, contained)

        expect(result).to eq('Blood')
      end
    end

    context 'when all specimen references in array are nil' do
      it 'returns an empty string' do
        record = {
          'specimen' => [
            { 'reference' => nil },
            { 'reference' => nil }
          ]
        }
        contained = [
          { 'resourceType' => 'Specimen', 'id' => '123', 'type' => { 'text' => 'Blood' } }
        ]

        result = adapter.send(:get_sample_tested, record, contained)

        expect(result).to eq('')
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

  describe '#get_reference_id' do
    it 'extracts the ID from a full reference format' do
      expect(adapter.send(:get_reference_id, 'Organization/abc-123')).to eq('abc-123')
    end

    it 'returns the reference as-is when it has no slash (bare ID)' do
      expect(adapter.send(:get_reference_id, 'abc-123')).to eq('abc-123')
    end

    it 'returns nil when reference is nil' do
      expect(adapter.send(:get_reference_id, nil)).to be_nil
    end

    it 'returns nil when reference is an empty string' do
      expect(adapter.send(:get_reference_id, '')).to be_nil
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

  describe '#parse_single_record test_code_display mapping' do
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

      it 'maps MB to "Microbiology" (Oracle Health format)' do
        record = base_record.deep_dup
        record['resource']['category'] = [{ 'coding' => [{ 'code' => 'MB' }] }]

        result = adapter.send(:parse_single_record, record)

        expect(result.test_code).to eq('MB')
        expect(result.test_code_display).to eq('Microbiology')
      end

      it 'maps LP29684-5 to "Radiology" (LOINC code)' do
        record = base_record.deep_dup
        record['resource']['category'] = [{ 'coding' => [{ 'code' => 'LP29684-5' }] }]

        result = adapter.send(:parse_single_record, record)

        expect(result.test_code).to eq('LP29684-5')
        expect(result.test_code_display).to eq('Radiology')
      end
    end

    context 'with VistA URN format codes' do
      it 'preserves raw URN in test_code but maps to "Microbiology" in test_code_display' do
        record = base_record.deep_dup
        record['resource']['category'] = [{ 'coding' => [{ 'code' => 'urn:va:lab-category:MI' }] }]

        result = adapter.send(:parse_single_record, record)

        expect(result.test_code).to eq('urn:va:lab-category:MI')
        expect(result.test_code_display).to eq('Microbiology')
      end

      it 'preserves raw URN in test_code but maps to "Chemistry and hematology" in test_code_display' do
        record = base_record.deep_dup
        record['resource']['category'] = [{ 'coding' => [{ 'code' => 'urn:va:lab-category:CH' }] }]

        result = adapter.send(:parse_single_record, record)

        expect(result.test_code).to eq('urn:va:lab-category:CH')
        expect(result.test_code_display).to eq('Chemistry and hematology')
      end

      it 'preserves raw URN in test_code but maps to "Surgical Pathology" in test_code_display' do
        record = base_record.deep_dup
        record['resource']['category'] = [{ 'coding' => [{ 'code' => 'urn:va:lab-category:SP' }] }]

        result = adapter.send(:parse_single_record, record)

        expect(result.test_code).to eq('urn:va:lab-category:SP')
        expect(result.test_code_display).to eq('Surgical Pathology')
      end

      it 'falls back to category.coding.display for unknown VistA URN codes' do
        record = base_record.deep_dup
        record['resource']['category'] = [{
          'coding' => [{ 'code' => 'urn:va:lab-category:XX', 'display' => 'Unknown Lab Type' }]
        }]

        result = adapter.send(:parse_single_record, record)

        expect(result.test_code).to eq('urn:va:lab-category:XX')
        expect(result.test_code_display).to eq('Unknown Lab Type')
      end

      it 'falls back to extracted code for unknown VistA URN when no display available' do
        record = base_record.deep_dup
        record['resource']['category'] = [{ 'coding' => [{ 'code' => 'urn:va:lab-category:XX' }] }]

        result = adapter.send(:parse_single_record, record)

        expect(result.test_code).to eq('urn:va:lab-category:XX')
        expect(result.test_code_display).to eq('XX')
      end
    end

    context 'with unknown test codes' do
      it 'falls back to category.coding.display when code is not in map' do
        record = base_record.deep_dup
        record['resource']['category'] = [{
          'coding' => [{ 'code' => 'NEWCODE', 'display' => 'New Test Category' }]
        }]

        result = adapter.send(:parse_single_record, record)

        expect(result.test_code).to eq('NEWCODE')
        expect(result.test_code_display).to eq('New Test Category')
      end

      it 'falls back to category.text when code is not in map and no display' do
        record = base_record.deep_dup
        record['resource']['category'] = [{
          'coding' => [{ 'code' => 'NEWCODE' }],
          'text' => 'Category Text Fallback'
        }]

        result = adapter.send(:parse_single_record, record)

        expect(result.test_code).to eq('NEWCODE')
        expect(result.test_code_display).to eq('Category Text Fallback')
      end

      it 'falls back to normalized code when no display or text available' do
        record = base_record.deep_dup
        record['resource']['category'] = [{ 'coding' => [{ 'code' => 'UNKNOWN' }] }]

        result = adapter.send(:parse_single_record, record)

        expect(result.test_code).to eq('UNKNOWN')
        expect(result.test_code_display).to eq('UNKNOWN')
      end

      it 'prefers explicit map over category.coding.display' do
        record = base_record.deep_dup
        record['resource']['category'] = [{
          'coding' => [{ 'code' => 'CH', 'display' => 'Chemistry' }]
        }]

        result = adapter.send(:parse_single_record, record)

        expect(result.test_code).to eq('CH')
        expect(result.test_code_display).to eq('Chemistry and hematology')
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
      it 'returns nil when no presentedForm exists' do
        resource = {}

        result = adapter.send(:get_date_completed, resource)

        expect(result).to be_nil
      end
    end

    context 'when effectivePeriod exists but has no start' do
      it 'returns nil when no presentedForm exists' do
        resource = { 'effectivePeriod' => { 'end' => '2025-06-24T15:21:00.000Z' } }

        result = adapter.send(:get_date_completed, resource)

        expect(result).to be_nil
      end
    end

    context 'when falling back to presentedForm creation date' do
      it 'returns the creation date from text/plain presentedForm' do
        resource = {
          'presentedForm' => [
            { 'contentType' => 'text/plain', 'creation' => '2024-12-05T12:50:00+00:00', 'data' => 'encoded' }
          ]
        }

        result = adapter.send(:get_date_completed, resource)

        expect(result).to eq('2024-12-05T12:50:00+00:00')
      end

      it 'returns nil when presentedForm has no text/plain entry' do
        resource = {
          'presentedForm' => [
            { 'contentType' => 'application/pdf', 'creation' => '2024-12-05T12:50:00+00:00' }
          ]
        }

        result = adapter.send(:get_date_completed, resource)

        expect(result).to be_nil
      end

      it 'returns nil when text/plain entry has no creation date' do
        resource = {
          'presentedForm' => [
            { 'contentType' => 'text/plain', 'data' => 'encoded' }
          ]
        }

        result = adapter.send(:get_date_completed, resource)

        expect(result).to be_nil
      end

      it 'prefers effectiveDateTime over presentedForm creation' do
        resource = {
          'effectiveDateTime' => '2025-01-01T00:00:00Z',
          'presentedForm' => [
            { 'contentType' => 'text/plain', 'creation' => '2024-12-05T12:50:00+00:00' }
          ]
        }

        result = adapter.send(:get_date_completed, resource)

        expect(result).to eq('2025-01-01T00:00:00Z')
      end
    end

    context 'with fixture data' do
      it 'falls back to presentedForm creation for radiology records without effectiveDateTime' do
        # vista[1] has no effectiveDateTime or effectivePeriod but has presentedForm with creation
        radiology_record = labs_response['vista']['entry'][1]
        resource = radiology_record['resource']

        expect(resource['effectiveDateTime']).to be_nil
        expect(resource['effectivePeriod']).to be_nil

        result = adapter.send(:get_date_completed, resource)

        expect(result).to eq('2024-12-05T12:50:00+00:00')
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

  describe '#extract_station_number' do
    it 'extracts station number from SN= format' do
      contained = [
        {
          'resourceType' => 'Practitioner',
          'id' => 'prac-123',
          'identifier' => [
            { 'type' => { 'text' => 'OTHER' }, 'value' => 'SN=668' }
          ]
        }
      ]

      result = adapter.send(:extract_station_number, contained)
      expect(result).to eq('668')
    end

    it 'extracts station number from plain 3-digit format with OTHER type' do
      contained = [
        {
          'resourceType' => 'Practitioner',
          'id' => 'prac-123',
          'identifier' => [
            { 'type' => { 'text' => 'Personnel Primary Identifier' }, 'value' => '2116663646' },
            { 'type' => { 'text' => 'OTHER' }, 'value' => '668' }
          ]
        }
      ]

      result = adapter.send(:extract_station_number, contained)
      expect(result).to eq('668')
    end

    it 'prioritizes SN= format over plain format' do
      contained = [
        {
          'resourceType' => 'Practitioner',
          'id' => 'prac-123',
          'identifier' => [
            { 'type' => { 'text' => 'OTHER' }, 'value' => '999' },
            { 'type' => { 'text' => 'OTHER' }, 'value' => 'SN=668' }
          ]
        }
      ]

      result = adapter.send(:extract_station_number, contained)
      expect(result).to eq('668')
    end

    it 'falls back to Organization when no Practitioner exists' do
      contained = [
        {
          'resourceType' => 'Organization',
          'id' => 'org-1',
          'identifier' => [
            { 'system' => 'urn:oid:2.16.840.1.113883.4.349', 'value' => '989' }
          ]
        }
      ]

      result = adapter.send(:extract_station_number, contained)
      expect(result).to eq('989')
    end

    it 'returns nil when neither Practitioner nor Organization have valid identifiers' do
      contained = [
        { 'resourceType' => 'Organization', 'id' => 'org-1', 'name' => 'Test Lab' }
      ]

      result = adapter.send(:extract_station_number, contained)
      expect(result).to be_nil
    end

    it 'returns nil when Practitioner has no identifiers' do
      contained = [
        { 'resourceType' => 'Practitioner', 'id' => 'prac-123', 'name' => [{ 'family' => 'Smith' }] }
      ]

      result = adapter.send(:extract_station_number, contained)
      expect(result).to be_nil
    end

    it 'returns nil when contained is blank' do
      expect(adapter.send(:extract_station_number, nil)).to be_nil
      expect(adapter.send(:extract_station_number, [])).to be_nil
    end

    it 'extracts station number with letter suffix from OTHER identifier' do
      contained = [
        {
          'resourceType' => 'Practitioner',
          'id' => 'prac-123',
          'identifier' => [
            { 'type' => { 'text' => 'OTHER' }, 'value' => '668A' }
          ]
        }
      ]

      result = adapter.send(:extract_station_number, contained)
      expect(result).to eq('668A')
    end

    it 'extracts station number with two-letter suffix from OTHER identifier' do
      contained = [
        {
          'resourceType' => 'Practitioner',
          'id' => 'prac-123',
          'identifier' => [
            { 'type' => { 'text' => 'OTHER' }, 'value' => '668GC' }
          ]
        }
      ]

      result = adapter.send(:extract_station_number, contained)
      expect(result).to eq('668GC')
    end

    it 'ignores identifiers with more than 2 letter suffix' do
      contained = [
        {
          'resourceType' => 'Practitioner',
          'id' => 'prac-123',
          'identifier' => [
            { 'type' => { 'text' => 'OTHER' }, 'value' => '668ABC' }
          ]
        }
      ]

      result = adapter.send(:extract_station_number, contained)
      expect(result).to be_nil
    end

    it 'ignores non-station-number OTHER identifiers' do
      contained = [
        {
          'resourceType' => 'Practitioner',
          'id' => 'prac-123',
          'identifier' => [
            { 'type' => { 'text' => 'OTHER' }, 'value' => '1000690375' },
            { 'type' => { 'text' => 'Messaging' }, 'value' => '8305155' }
          ]
        }
      ]

      result = adapter.send(:extract_station_number, contained)
      expect(result).to be_nil
    end

    context 'with Organization fallback (VistA data)' do
      it 'extracts station number from Organization with VA OID system' do
        contained = [
          {
            'resourceType' => 'Organization',
            'id' => 'org-123',
            'identifier' => [
              { 'use' => 'usual', 'system' => 'urn:oid:2.16.840.1.113883.4.349', 'value' => '989' }
            ],
            'name' => 'CHYSHR TEST LAB'
          }
        ]

        result = adapter.send(:extract_station_number, contained)
        expect(result).to eq('989')
      end

      it 'returns nil when Organization has no VA OID identifier' do
        contained = [
          {
            'resourceType' => 'Organization',
            'id' => 'org-123',
            'identifier' => [
              { 'use' => 'usual', 'system' => 'some-other-system', 'value' => '123' }
            ],
            'name' => 'Test Lab'
          }
        ]

        result = adapter.send(:extract_station_number, contained)
        expect(result).to be_nil
      end

      it 'prioritizes Practitioner over Organization' do
        contained = [
          {
            'resourceType' => 'Practitioner',
            'id' => 'prac-123',
            'identifier' => [
              { 'type' => { 'text' => 'OTHER' }, 'value' => 'SN=668' }
            ]
          },
          {
            'resourceType' => 'Organization',
            'id' => 'org-123',
            'identifier' => [
              { 'use' => 'usual', 'system' => 'urn:oid:2.16.840.1.113883.4.349', 'value' => '989' }
            ]
          }
        ]

        result = adapter.send(:extract_station_number, contained)
        expect(result).to eq('668')
      end

      it 'falls back to Organization when Practitioner has no station number' do
        contained = [
          {
            'resourceType' => 'Practitioner',
            'id' => 'prac-123',
            'identifier' => [
              { 'extension' => [{ 'url' => 'http://hl7.org/fhir/StructureDefinition/data-absent-reason',
                                  'valueCode' => 'unknown' }] }
            ]
          },
          {
            'resourceType' => 'Organization',
            'id' => 'org-123',
            'identifier' => [
              { 'use' => 'usual', 'system' => 'urn:oid:2.16.840.1.113883.4.349', 'value' => '989' }
            ]
          }
        ]

        result = adapter.send(:extract_station_number, contained)
        expect(result).to eq('989')
      end

      it 'falls back to Organization when no Practitioner exists' do
        contained = [
          {
            'resourceType' => 'Organization',
            'id' => 'org-123',
            'identifier' => [
              { 'use' => 'usual', 'system' => 'urn:oid:2.16.840.1.113883.4.349', 'value' => '500' }
            ]
          },
          { 'resourceType' => 'ServiceRequest', 'id' => 'sr-1' }
        ]

        result = adapter.send(:extract_station_number, contained)
        expect(result).to eq('500')
      end
    end
  end

  describe '#extract_station_number_from_record' do
    it 'extracts station number from a full record structure' do
      record = {
        'resource' => {
          'contained' => [
            {
              'resourceType' => 'Practitioner',
              'identifier' => [
                { 'type' => { 'text' => 'OTHER' }, 'value' => 'SN=668' }
              ]
            }
          ]
        }
      }

      result = adapter.extract_station_number_from_record(record)
      expect(result).to eq('668')
    end

    it 'returns nil when record has no contained resources' do
      record = { 'resource' => {} }

      result = adapter.extract_station_number_from_record(record)
      expect(result).to be_nil
    end

    it 'returns nil when record is nil' do
      result = adapter.extract_station_number_from_record(nil)
      expect(result).to be_nil
    end
  end

  describe '#extract_station_from_practitioner' do
    it 'extracts station number from SN= format' do
      contained = [
        {
          'resourceType' => 'Practitioner',
          'id' => 'prac-123',
          'identifier' => [
            { 'type' => { 'text' => 'OTHER' }, 'value' => 'SN=668' }
          ]
        }
      ]

      result = adapter.send(:extract_station_from_practitioner, contained)
      expect(result).to eq('668')
    end

    it 'returns nil when no Practitioner exists' do
      contained = [{ 'resourceType' => 'Organization', 'id' => 'org-1' }]

      result = adapter.send(:extract_station_from_practitioner, contained)
      expect(result).to be_nil
    end
  end

  describe '#extract_station_from_organization' do
    it 'extracts station number from Organization with VA OID system' do
      contained = [
        {
          'resourceType' => 'Organization',
          'id' => 'org-123',
          'identifier' => [
            { 'use' => 'usual', 'system' => 'urn:oid:2.16.840.1.113883.4.349', 'value' => '989' }
          ]
        }
      ]

      result = adapter.send(:extract_station_from_organization, contained)
      expect(result).to eq('989')
    end

    it 'returns nil when Organization has no identifiers' do
      contained = [
        { 'resourceType' => 'Organization', 'id' => 'org-123', 'name' => 'Test Lab' }
      ]

      result = adapter.send(:extract_station_from_organization, contained)
      expect(result).to be_nil
    end

    it 'returns nil when no Organization exists' do
      contained = [{ 'resourceType' => 'Practitioner', 'id' => 'prac-1' }]

      result = adapter.send(:extract_station_from_organization, contained)
      expect(result).to be_nil
    end

    it 'ignores identifiers without VA OID system' do
      contained = [
        {
          'resourceType' => 'Organization',
          'id' => 'org-123',
          'identifier' => [
            { 'system' => 'http://some-other-system.com', 'value' => '12345' }
          ]
        }
      ]

      result = adapter.send(:extract_station_from_organization, contained)
      expect(result).to be_nil
    end
  end

  describe '#get_facility_timezone' do
    it 'returns nil when station_number is blank' do
      expect(adapter.send(:get_facility_timezone, nil)).to be_nil
      expect(adapter.send(:get_facility_timezone, '')).to be_nil
    end

    context 'when facility service returns timezone' do
      before do
        allow_any_instance_of(UnifiedHealthData::FacilityService)
          .to receive(:get_facility_timezone)
          .with('668')
          .and_return('America/Los_Angeles')
      end

      it 'returns the timezone from facility service' do
        result = adapter.send(:get_facility_timezone, '668')
        expect(result).to eq('America/Los_Angeles')
      end
    end

    context 'when facility service returns nil' do
      before do
        allow_any_instance_of(UnifiedHealthData::FacilityService)
          .to receive(:get_facility_timezone)
          .with('999')
          .and_return(nil)
      end

      it 'returns nil' do
        result = adapter.send(:get_facility_timezone, '999')
        expect(result).to be_nil
      end
    end
  end

  describe '#convert_to_facility_time' do
    it 'converts UTC time to facility local time' do
      # UTC time: 2023-11-06T18:32:00+00:00 (6:32 PM UTC)
      # Los Angeles is UTC-8 in November (PST), so local time should be 10:32 AM
      result = adapter.send(:convert_to_facility_time, '2023-11-06T18:32:00+00:00', 'America/Los_Angeles')

      parsed = DateTime.parse(result)
      expect(parsed.hour).to eq(10)
      expect(parsed.min).to eq(32)
      expect(result).to include('-08:00')
    end

    it 'converts UTC time to Eastern time' do
      # UTC time: 2023-11-06T18:32:00+00:00 (6:32 PM UTC)
      # New York is UTC-5 in November (EST), so local time should be 1:32 PM
      result = adapter.send(:convert_to_facility_time, '2023-11-06T18:32:00+00:00', 'America/New_York')

      parsed = DateTime.parse(result)
      expect(parsed.hour).to eq(13)
      expect(parsed.min).to eq(32)
      expect(result).to include('-05:00')
    end

    it 'converts UTC time with Z suffix' do
      # Common format from SCDF: 2023-11-06T18:32:00.000Z
      result = adapter.send(:convert_to_facility_time, '2023-11-06T18:32:00.000Z', 'America/Los_Angeles')

      parsed = DateTime.parse(result)
      expect(parsed.hour).to eq(10)
      expect(parsed.min).to eq(32)
    end

    it 'correctly handles dates that already have non-UTC offsets' do
      # If the incoming date has -04:00 offset (e.g., from previous conversion or different source)
      # it should still convert correctly to the target timezone
      # 2023-11-06T14:32:00-04:00 = 2023-11-06T18:32:00 UTC = 2023-11-06T10:32:00 PST
      result = adapter.send(:convert_to_facility_time, '2023-11-06T14:32:00-04:00', 'America/Los_Angeles')

      parsed = DateTime.parse(result)
      expect(parsed.hour).to eq(10)
      expect(parsed.min).to eq(32)
      expect(result).to include('-08:00')
    end

    it 'returns original date when timezone is blank' do
      original = '2023-11-06T18:32:00+00:00'
      expect(adapter.send(:convert_to_facility_time, original, nil)).to eq(original)
      expect(adapter.send(:convert_to_facility_time, original, '')).to eq(original)
    end

    it 'returns original date when date_string is blank' do
      expect(adapter.send(:convert_to_facility_time, nil, 'America/New_York')).to be_nil
      expect(adapter.send(:convert_to_facility_time, '', 'America/New_York')).to eq('')
    end

    it 'returns original date and logs warning on parse error' do
      invalid_date = 'not-a-date'

      expect(Rails.logger).to receive(:warn).with(
        /Failed to convert time to facility timezone/,
        hash_including(service: 'unified_health_data')
      )

      result = adapter.send(:convert_to_facility_time, invalid_date, 'America/New_York')
      expect(result).to eq(invalid_date)
    end

    it 'returns original date and logs warning on invalid timezone' do
      valid_date = '2023-11-06T18:32:00+00:00'
      invalid_timezone = 'Invalid/Timezone'

      expect(Rails.logger).to receive(:warn).with(
        /Failed to convert time to facility timezone/,
        hash_including(service: 'unified_health_data', timezone: invalid_timezone)
      )

      result = adapter.send(:convert_to_facility_time, valid_date, invalid_timezone)
      expect(result).to eq(valid_date)
    end
  end

  describe 'facility_timezone integration' do
    let(:record_with_practitioner) do
      {
        'resource' => {
          'resourceType' => 'DiagnosticReport',
          'id' => 'test-tz-123',
          'status' => 'final',
          'category' => [{ 'coding' => [{ 'code' => 'CH' }] }],
          'code' => { 'text' => 'Lab Report' },
          'effectiveDateTime' => '2023-11-06T18:32:00+00:00',
          'presentedForm' => [{ 'contentType' => 'text/plain', 'data' => 'test_data' }],
          'contained' => [
            {
              'resourceType' => 'Practitioner',
              'id' => 'prac-8305155',
              'identifier' => [
                { 'type' => { 'text' => 'Personnel Primary Identifier' }, 'value' => '2116663646' },
                { 'type' => { 'text' => 'OTHER' }, 'value' => '668' },
                { 'type' => { 'text' => 'OTHER' }, 'value' => 'SN=668' }
              ],
              'name' => [{ 'given' => ['Steve'], 'family' => 'Skojec' }]
            }
          ]
        },
        'source' => 'oracle-health'
      }
    end

    context 'when facility lookup succeeds' do
      before do
        allow_any_instance_of(UnifiedHealthData::FacilityService)
          .to receive(:get_facility_timezone)
          .with('668')
          .and_return('America/Los_Angeles')
      end

      it 'includes facility_timezone in parsed record' do
        result = adapter.send(:parse_single_record, record_with_practitioner)

        expect(result.facility_timezone).to eq('America/Los_Angeles')
      end

      it 'converts date_completed to facility local time' do
        result = adapter.send(:parse_single_record, record_with_practitioner)

        # Original UTC: 2023-11-06T18:32:00+00:00
        # Los Angeles PST (UTC-8): 2023-11-06T10:32:00-08:00
        expect(result.date_completed).to include('10:32')
        expect(result.date_completed).to include('-08:00')
      end
    end

    context 'when facility lookup fails' do
      before do
        allow_any_instance_of(UnifiedHealthData::FacilityService)
          .to receive(:get_facility_timezone)
          .and_return(nil)
      end

      it 'sets facility_timezone to nil' do
        result = adapter.send(:parse_single_record, record_with_practitioner)

        expect(result.facility_timezone).to be_nil
      end

      it 'keeps original UTC date_completed' do
        result = adapter.send(:parse_single_record, record_with_practitioner)

        expect(result.date_completed).to eq('2023-11-06T18:32:00+00:00')
      end
    end

    context 'when no Practitioner in contained' do
      let(:record_without_practitioner) do
        {
          'resource' => {
            'resourceType' => 'DiagnosticReport',
            'id' => 'test-no-prac',
            'status' => 'final',
            'category' => [{ 'coding' => [{ 'code' => 'CH' }] }],
            'code' => { 'text' => 'Lab Report' },
            'effectiveDateTime' => '2023-11-06T18:32:00+00:00',
            'presentedForm' => [{ 'contentType' => 'text/plain', 'data' => 'test_data' }],
            'contained' => [
              { 'resourceType' => 'Organization', 'id' => 'org-1', 'name' => 'Test Lab' }
            ]
          },
          'source' => 'oracle-health'
        }
      end

      it 'sets facility_timezone to nil and keeps original date' do
        result = adapter.send(:parse_single_record, record_without_practitioner)

        expect(result.facility_timezone).to be_nil
        expect(result.date_completed).to eq('2023-11-06T18:32:00+00:00')
      end
    end

    context 'with VistA data (Organization fallback)' do
      let(:vista_record_with_organization) do
        {
          'resource' => {
            'resourceType' => 'DiagnosticReport',
            'id' => 'vista-lab-123',
            'status' => 'final',
            'category' => [{ 'coding' => [{ 'code' => 'urn:va:lab-category:CH' }] }],
            'code' => { 'text' => 'HEMOGLOBIN A1C' },
            'effectiveDateTime' => '2025-01-23T22:06:02Z',
            'presentedForm' => [{ 'contentType' => 'text/plain', 'data' => 'test_data' }],
            'contained' => [
              {
                'resourceType' => 'Organization',
                'id' => 'org-vista',
                'identifier' => [
                  { 'use' => 'usual', 'system' => 'urn:oid:2.16.840.1.113883.4.349', 'value' => '989' }
                ],
                'name' => 'CHYSHR TEST LAB'
              }
            ]
          },
          'source' => 'vista'
        }
      end

      context 'when facility lookup succeeds via Organization' do
        before do
          allow_any_instance_of(UnifiedHealthData::FacilityService)
            .to receive(:get_facility_timezone)
            .with('989')
            .and_return('America/Chicago')
        end

        it 'extracts station number from Organization and sets facility_timezone' do
          result = adapter.send(:parse_single_record, vista_record_with_organization)

          expect(result.facility_timezone).to eq('America/Chicago')
        end

        it 'converts date_completed to facility local time' do
          result = adapter.send(:parse_single_record, vista_record_with_organization)

          # Original UTC: 2025-01-23T22:06:02Z
          # Chicago CST (UTC-6): 2025-01-23T16:06:02-06:00
          expect(result.date_completed).to include('16:06')
          expect(result.date_completed).to include('-06:00')
        end
      end

      context 'when facility lookup fails' do
        before do
          allow_any_instance_of(UnifiedHealthData::FacilityService)
            .to receive(:get_facility_timezone)
            .and_return(nil)
        end

        it 'keeps original UTC date_completed' do
          result = adapter.send(:parse_single_record, vista_record_with_organization)

          expect(result.facility_timezone).to be_nil
          expect(result.date_completed).to eq('2025-01-23T22:06:02Z')
        end
      end
    end
  end
end
