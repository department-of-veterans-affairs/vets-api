# frozen_string_literal: true

require 'rails_helper'
require 'unified_health_data/service'

describe UnifiedHealthData::Service, type: :service do
  subject { described_class }

  let(:user) { build(:user, :loa3) }
  let(:service) { described_class.new(user) }
  let(:labs_response) do
    file_path = Rails.root.join('spec', 'fixtures', 'unified_health_data', 'labs_response.json')
    JSON.parse(File.read(file_path))
  end
  let(:sample_response) do
    JSON.parse(Rails.root.join(
      'spec', 'fixtures', 'unified_health_data', 'sample_response.json'
    ).read)
  end

  describe '#get_labs' do
    context 'with defensive nil checks' do
      it 'handles missing contained sections' do
        # Simulate missing contained by modifying the response
        modified_response = JSON.parse(sample_response.to_json)
        modified_response['vista']['entry'].first['resource']['contained'] = nil
        allow(service).to receive_messages(fetch_access_token: 'token', perform: double(body: sample_response),
                                           parse_response_body: modified_response)

        expect do
          labs = service.get_labs(start_date: '2024-01-01', end_date: '2025-05-31')
          expect(labs).to be_an(Array)
        end.not_to raise_error
      end
    end

    context 'with valid lab responses' do
      before do
        allow(service).to receive_messages(fetch_access_token: 'token', perform: double(body: labs_response),
                                           parse_response_body: labs_response)
      end

      context 'when Flipper is enabled for both codes' do
        it 'returns labs/tests' do
          allow(Flipper).to receive(:enabled?).with(:mhv_accelerated_delivery_uhd_ch_enabled, user).and_return(true)
          allow(Flipper).to receive(:enabled?).with(:mhv_accelerated_delivery_uhd_sp_enabled, user).and_return(true)
          labs = service.get_labs(start_date: '2024-01-01', end_date: '2025-05-31')
          expect(labs.size).to eq(2)
          expect(labs.map { |l| l.attributes.test_code }).to contain_exactly('CH', 'SP')
        end
      end

      context 'when Flipper is disabled for both codes' do
        it 'filters out labs/tests' do
          allow(Flipper).to receive(:enabled?).with(:mhv_accelerated_delivery_uhd_ch_enabled, user).and_return(false)
          allow(Flipper).to receive(:enabled?).with(:mhv_accelerated_delivery_uhd_sp_enabled, user).and_return(false)
          labs = service.get_labs(start_date: '2024-01-01', end_date: '2025-05-31')
          expect(labs).to be_empty
        end
      end

      context 'when only one Flipper is enabled' do
        it 'returns only enabled test codes' do
          allow(Flipper).to receive(:enabled?).with(:mhv_accelerated_delivery_uhd_ch_enabled, user).and_return(true)
          allow(Flipper).to receive(:enabled?).with(:mhv_accelerated_delivery_uhd_sp_enabled, user).and_return(false)
          labs = service.get_labs(start_date: '2024-01-01', end_date: '2025-05-31')
          expect(labs.size).to eq(1)
          expect(labs.first.attributes.test_code).to eq('CH')
        end
      end
    end

    context 'with malformed response' do
      before do
        allow(service).to receive_messages(fetch_access_token: 'token', perform: double(body: nil))
      end

      it 'handles gracefully' do
        allow(service).to receive(:parse_response_body).and_return(nil)
        allow(Flipper).to receive(:enabled?).and_return(true)
        expect { service.get_labs(start_date: '2024-01-01', end_date: '2025-05-31') }.not_to raise_error
      end
    end
  end

  describe '#filter_records' do
    let(:record_ch) { double(attributes: double(test_code: 'CH')) }
    let(:record_sp) { double(attributes: double(test_code: 'SP')) }
    let(:records) { [record_ch, record_sp] }

    it 'returns only records with enabled Flipper flags' do
      allow(Flipper).to receive(:enabled?).with(:mhv_accelerated_delivery_uhd_ch_enabled, user).and_return(true)
      allow(Flipper).to receive(:enabled?).with(:mhv_accelerated_delivery_uhd_sp_enabled, user).and_return(false)
      result = service.send(:filter_records, records)
      expect(result).to eq([record_ch])
    end
  end

  describe '#fetch_location' do
    it 'returns the organization name if present' do
      record = { 'resource' => { 'contained' => [{ 'resourceType' => 'Organization', 'name' => 'LabX' }] } }
      expect(service.send(:fetch_location, record)).to eq('LabX')
    end

    it 'returns nil if no organization' do
      record = { 'resource' => { 'contained' => [{ 'resourceType' => 'Other' }] } }
      expect(service.send(:fetch_location, record)).to be_nil
    end
  end

  describe '#fetch_ordered_by' do
    it 'returns practitioner full name if present' do
      record = { 'resource' => { 'contained' => [{ 'resourceType' => 'Practitioner',
                                                   'name' => [{ 'given' => ['A'], 'family' => 'B' }] }] } }
      expect(service.send(:fetch_ordered_by, record)).to eq('A B')
    end

    it 'returns nil if no practitioner' do
      record = { 'resource' => { 'contained' => [{ 'resourceType' => 'Other' }] } }
      expect(service.send(:fetch_ordered_by, record)).to be_nil
    end
  end

  describe '#fetch_observation_value' do
    it 'returns quantity type and text' do
      obs = { 'valueQuantity' => { 'value' => 5, 'unit' => 'mg' } }
      expect(service.send(:fetch_observation_value, obs)).to eq({ type: 'quantity', text: '5 mg' })
    end

    it 'returns codeable-concept type and text' do
      obs = { 'valueCodeableConcept' => { 'text' => 'POS' } }
      expect(service.send(:fetch_observation_value, obs)).to eq({ type: 'codeable-concept', text: 'POS' })
    end

    it 'returns string type and text' do
      obs = { 'valueString' => 'abc' }
      expect(service.send(:fetch_observation_value, obs)).to eq({ type: 'string', text: 'abc' })
    end

    it 'returns date-time type and text' do
      obs = { 'valueDateTime' => '2024-06-01T00:00:00Z' }
      expect(service.send(:fetch_observation_value, obs)).to eq({ type: 'date-time', text: '2024-06-01T00:00:00Z' })
    end

    it 'returns nils for unsupported types' do
      obs = {}
      expect(service.send(:fetch_observation_value, obs)).to eq({ type: nil, text: nil })
    end
  end

  describe '#fetch_body_site' do
    context 'when contained is nil' do
      it 'returns an empty string' do
        resource = { 'basedOn' => [{ 'reference' => 'ServiceRequest/123' }] }
        contained = nil

        result = service.send(:fetch_body_site, resource, contained)

        expect(result).to eq('')
      end
    end

    context 'when basedOn is nil' do
      it 'returns an empty string' do
        resource = {}
        contained = [{ 'resourceType' => 'ServiceRequest', 'id' => '123' }]

        result = service.send(:fetch_body_site, resource, contained)

        expect(result).to eq('')
      end
    end
  end

  describe '#fetch_sample_tested' do
    context 'when contained is nil' do
      it 'returns an empty string' do
        record = { 'specimen' => { 'reference' => 'Specimen/123' } }
        contained = nil

        result = service.send(:fetch_sample_tested, record, contained)

        expect(result).to eq('')
      end
    end

    context 'when specimen is nil' do
      it 'returns an empty string' do
        record = {}
        contained = [{ 'resourceType' => 'Specimen', 'id' => '123' }]

        result = service.send(:fetch_sample_tested, record, contained)

        expect(result).to eq('')
      end
    end
  end

  describe '#fetch_observations' do
    context 'when contained is nil' do
      it 'returns an empty array' do
        record = { 'resource' => { 'contained' => nil } }

        result = service.send(:fetch_observations, record)

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
        result = service.send(:fetch_observations, record)
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
        result = service.send(:fetch_observations, record)
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
        result = service.send(:fetch_observations, record)
        expect(result.size).to eq(1)
        expect(result.first.reference_range).to eq('Normal Range: 0.7 mIU/L - 4.5 mIU/L')
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
        result = service.send(:fetch_observations, record)
        expect(result.size).to eq(1)
        expect(result.first.reference_range).to eq(
          'Normal Range: 0.7 mIU/L - 4.5 mIU/L, ' \
          'Treatment Range: 0.5 mIU/L - 5.0 mIU/L'
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
        result = service.send(:fetch_observations, record)
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
        result = service.send(:fetch_observations, record)
        expect(result.size).to eq(1)
        expect(result.first.reference_range).to eq('>= 94')
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
        result = service.send(:fetch_observations, record)
        expect(result.size).to eq(1)
        expect(result.first.reference_range).to eq('<= 120')
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
                  { 'text' => 'Text-only range' },
                  {
                    'low' => { 'value' => 1 },
                    'high' => { 'value' => 10 }
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
        result = service.send(:fetch_observations, record)
        expect(result.size).to eq(1)
        expect(result.first.reference_range).to eq('Text-only range, 1 - 10, >= 2, <= 8')
      end

      it 'handles multiple reference ranges with different types' do
        obs = {
          'referenceRange' => [
            {
              'low' => { 'value' => 14 },
              'high' => { 'value' => 20 },
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
              'low' => { 'value' => 1000 },
              'high' => { 'value' => 2000 },
              'type' => {
                'coding' => [
                  {
                    'system' => 'http://terminology.hl7.org/CodeSystem/referencerange-meaning',
                    'code' => 'critical',
                    'display' => 'Critical Range'
                  }
                ],
                'text' => 'Critical Range'
              }
            }
          ]
        }
        result = service.send(:fetch_reference_range, obs)
        expect(result).to eq('Normal Range: 14 - 20, Critical Range: 1000 - 2000')
      end

      it 'handles multiple high-only reference ranges with different types' do
        obs = {
          'referenceRange' => [
            {
              'high' => { 'value' => 20 },
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
              'high' => { 'value' => 2000 },
              'type' => {
                'coding' => [
                  {
                    'system' => 'http://terminology.hl7.org/CodeSystem/referencerange-meaning',
                    'code' => 'critical',
                    'display' => 'Critical Range'
                  }
                ],
                'text' => 'Critical Range'
              }
            }
          ]
        }
        result = service.send(:fetch_reference_range, obs)
        expect(result).to eq('<= 20, Critical Range: <= 2000')
      end
    end
  end

  describe '#fetch_reference_range' do
    it 'returns empty string when referenceRange is nil' do
      obs = {}
      result = service.send(:fetch_reference_range, obs)
      expect(result).to eq('')
    end

    it 'returns text directly when available' do
      obs = {
        'referenceRange' => [
          { 'text' => '70-110 mg/dL' },
          { 'text' => '<=3' }
        ]
      }
      result = service.send(:fetch_reference_range, obs)
      expect(result).to eq('70-110 mg/dL, <=3')
    end

    it 'formats low-high values correctly' do
      obs = {
        'referenceRange' => [
          {
            'low' => { 'value' => 13.5, 'unit' => 'g/dL' },
            'high' => { 'value' => 18.0, 'unit' => 'g/dL' }
          }
        ]
      }
      result = service.send(:fetch_reference_range, obs)
      expect(result).to eq('13.5 - 18.0')
    end

    it 'formats low-only values correctly' do
      obs = {
        'referenceRange' => [
          {
            'low' => { 'value' => 94 }
          }
        ]
      }
      result = service.send(:fetch_reference_range, obs)
      expect(result).to eq('>= 94')
    end

    it 'formats high-only values correctly' do
      obs = {
        'referenceRange' => [
          {
            'high' => { 'value' => 44 }
          }
        ]
      }
      result = service.send(:fetch_reference_range, obs)
      expect(result).to eq('<= 44')
    end

    it 'handles empty low/high values gracefully' do
      obs = {
        'referenceRange' => [
          {
            'low' => {},
            'high' => {}
          }
        ]
      }
      result = service.send(:fetch_reference_range, obs)
      expect(result).to eq('')
    end

    it 'handles mixed formats correctly' do
      obs = {
        'referenceRange' => [
          { 'text' => 'Normal: <100 mg/dL' },
          {
            'low' => { 'value' => 5.0 },
            'high' => { 'value' => 7.5 }
          },
          {
            'low' => { 'value' => 4.0 }
          }
        ]
      }
      result = service.send(:fetch_reference_range, obs)
      expect(result).to eq('Normal: <100 mg/dL, 5.0 - 7.5, >= 4.0')
    end

    it 'gracefully handles malformed reference range data' do
      # Test with various types of malformed data
      test_cases = [
        # Nil reference range
        { 'referenceRange' => nil },

        # Empty array
        { 'referenceRange' => [] },

        # Non-array reference range
        { 'referenceRange' => 'not an array' },

        # Array with non-hash elements
        { 'referenceRange' => ['string', 123, nil] }
      ]

      test_cases.each do |test_case|
        result = service.send(:fetch_reference_range, test_case)
        expect(result).to eq(''), "Failed for test case: #{test_case.inspect}"
      end
    end

    it 'handles type field that is not a hash' do
      test_case = { 'referenceRange' => [{ 'low' => { 'value' => 10 }, 'type' => 'not a hash' }] }
      result = service.send(:fetch_reference_range, test_case)
      expect(result).to eq('>= 10')
    end

    it 'handles missing low and high fields' do
      test_case = { 'referenceRange' => [{ 'other_field' => 'some value' }] }
      result = service.send(:fetch_reference_range, test_case)
      expect(result).to eq('')
    end

    it 'handles non-numeric values in low/high' do
      test_case = { 'referenceRange' => [{ 'low' => { 'value' => 'not a number' },
                                           'high' => { 'value' => 'also not a number' } }] }
      result = service.send(:fetch_reference_range, test_case)
      expect(result).to eq('')
    end

    it 'handles malformed nested structures' do
      test_case = { 'referenceRange' => [{ 'low' => 'not a hash', 'high' => 123 }] }
      result = service.send(:fetch_reference_range, test_case)
      expect(result).to eq('')
    end

    it 'handles low value with no unit and type with no text' do
      test_case = { 'referenceRange' => [{ 'low' => { 'value' => 5 }, 'type' => { 'coding' => [{}] } }] }
      result = service.send(:fetch_reference_range, test_case)
      expect(result).to eq('>= 5')
    end
  end

  describe '#fetch_code' do
    context 'when category is nil' do
      it 'returns nil' do
        record = { 'resource' => { 'category' => nil } }

        result = service.send(:fetch_code, record)

        expect(result).to be_nil
      end
    end

    context 'when category is empty' do
      it 'returns nil' do
        record = { 'resource' => { 'category' => [] } }

        result = service.send(:fetch_code, record)

        expect(result).to be_nil
      end
    end
  end

  describe '#parse_single_record' do
    context 'when record is nil' do
      it 'returns nil' do
        result = service.send(:parse_single_record, nil)

        expect(result).to be_nil
      end
    end

    context 'when resource is nil' do
      it 'returns nil' do
        record = {}

        result = service.send(:parse_single_record, record)

        expect(result).to be_nil
      end
    end
  end

  describe '#parse_labs' do
    context 'when records is nil' do
      it 'returns an empty array' do
        result = service.send(:parse_labs, nil)

        expect(result).to eq([])
      end
    end

    context 'when records is empty' do
      it 'returns an empty array' do
        result = service.send(:parse_labs, [])

        expect(result).to eq([])
      end
    end
  end

  describe '#fetch_combined_records' do
    context 'when body is nil' do
      it 'returns an empty array' do
        result = service.send(:fetch_combined_records, nil)

        expect(result).to eq([])
      end
    end
  end

  describe '#fetch_display' do
    let(:service_instance) { described_class.new(user) }

    it 'returns ServiceRequest code text if present' do
      record = {
        'resource' => {
          'contained' => [
            { 'resourceType' => 'ServiceRequest', 'code' => { 'text' => 'Blood Test' } }
          ],
          'code' => { 'text' => 'Fallback Test' }
        }
      }
      expect(service_instance.send(:fetch_display, record)).to eq('Blood Test')
    end

    it 'returns code.text if ServiceRequest is not present' do
      record = {
        'resource' => {
          'contained' => [
            { 'resourceType' => 'OtherType' }
          ],
          'code' => { 'text' => 'Fallback Test' }
        }
      }
      expect(service_instance.send(:fetch_display, record)).to eq('Fallback Test')
    end

    it 'returns empty string if neither ServiceRequest nor code.text is present' do
      record = {
        'resource' => {
          'contained' => [
            { 'resourceType' => 'OtherType' }
          ]
        }
      }
      expect(service_instance.send(:fetch_display, record)).to eq('')
    end
  end
end
