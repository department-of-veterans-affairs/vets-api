# frozen_string_literal: true

require 'rails_helper'
require 'unified_health_data/service'

describe UnifiedHealthData::Service, type: :service do
  subject { described_class }

  let(:user) { build(:user, :loa3) }
  let(:service) { described_class.new(user) }

  describe '#get_labs' do
    let(:labs_response) do
      file_path = Rails.root.join('spec', 'fixtures', 'unified_health_data', 'labs_response.json')
      JSON.parse(File.read(file_path))
    end
    let(:sample_response) do
      JSON.parse(Rails.root.join(
        'spec', 'fixtures', 'unified_health_data', 'sample_response.json'
      ).read)
    end

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

      context 'when Flipper is enabled for all codes' do
        it 'returns labs/tests' do
          allow(Flipper).to receive(:enabled?).with(:mhv_accelerated_delivery_uhd_filtering_enabled,
                                                    user).and_return(true)
          allow(Flipper).to receive(:enabled?).with(:mhv_accelerated_delivery_uhd_ch_enabled, user).and_return(true)
          allow(Flipper).to receive(:enabled?).with(:mhv_accelerated_delivery_uhd_sp_enabled, user).and_return(true)
          allow(Flipper).to receive(:enabled?).with(:mhv_accelerated_delivery_uhd_mb_enabled, user).and_return(true)
          labs = service.get_labs(start_date: '2024-01-01', end_date: '2025-05-31')
          expect(labs.size).to eq(3)
          expect(labs.map { |l| l.attributes.test_code }).to contain_exactly('CH', 'SP', 'MB')
        end
      end

      context 'logs test code distribution' do
        it 'logs the test code distribution from parsed records' do
          allow(Flipper).to receive(:enabled?).with(:mhv_accelerated_delivery_uhd_filtering_enabled,
                                                    user).and_return(true)
          allow(Flipper).to receive(:enabled?).with(:mhv_accelerated_delivery_uhd_ch_enabled, user).and_return(true)
          allow(Flipper).to receive(:enabled?).with(:mhv_accelerated_delivery_uhd_sp_enabled, user).and_return(true)
          allow(Flipper).to receive(:enabled?).with(:mhv_accelerated_delivery_uhd_mb_enabled, user).and_return(true)
          allow(Rails.logger).to receive(:info)

          service.get_labs(start_date: '2024-01-01', end_date: '2025-05-31')

          expect(Rails.logger).to have_received(:info).with(
            hash_including(
              message: 'UHD test code and name distribution',
              service: 'unified_health_data'
            )
          )
        end
      end

      context 'when filtering is disabled' do
        it 'returns all labs/tests regardless of individual toggle states' do
          allow(Flipper).to receive(:enabled?).with(:mhv_accelerated_delivery_uhd_filtering_enabled,
                                                    user).and_return(false)
          allow(Flipper).to receive(:enabled?).with(:mhv_accelerated_delivery_uhd_ch_enabled, user).and_return(false)
          allow(Flipper).to receive(:enabled?).with(:mhv_accelerated_delivery_uhd_sp_enabled, user).and_return(false)
          allow(Flipper).to receive(:enabled?).with(:mhv_accelerated_delivery_uhd_mb_enabled, user).and_return(false)
          allow(Rails.logger).to receive(:info)

          labs = service.get_labs(start_date: '2024-01-01', end_date: '2025-05-31')

          expect(labs.size).to eq(3)
          expect(labs.map { |l| l.attributes.test_code }).to contain_exactly('CH', 'SP', 'MB')
          expect(Rails.logger).to have_received(:info).with(
            hash_including(
              message: 'UHD filtering disabled - returning all records',
              total_records: 3,
              service: 'unified_health_data'
            )
          )
        end

        it 'logs that filtering is disabled' do
          allow(Flipper).to receive(:enabled?).with(:mhv_accelerated_delivery_uhd_filtering_enabled,
                                                    user).and_return(false)
          allow(Rails.logger).to receive(:info)

          service.get_labs(start_date: '2024-01-01', end_date: '2025-05-31')

          expect(Rails.logger).to have_received(:info).with(
            hash_including(
              message: 'UHD filtering disabled - returning all records',
              service: 'unified_health_data'
            )
          )
        end
      end

      context 'when Flipper is disabled for all codes' do
        it 'filters out labs/tests' do
          allow(Flipper).to receive(:enabled?).with(:mhv_accelerated_delivery_uhd_filtering_enabled,
                                                    user).and_return(true)
          allow(Flipper).to receive(:enabled?).with(:mhv_accelerated_delivery_uhd_ch_enabled, user).and_return(false)
          allow(Flipper).to receive(:enabled?).with(:mhv_accelerated_delivery_uhd_sp_enabled, user).and_return(false)
          allow(Flipper).to receive(:enabled?).with(:mhv_accelerated_delivery_uhd_mb_enabled, user).and_return(false)
          allow(Rails.logger).to receive(:info)
          labs = service.get_labs(start_date: '2024-01-01', end_date: '2025-05-31')
          expect(labs).to be_empty
        end
      end

      context 'when only one Flipper is enabled' do
        it 'returns only enabled test codes' do
          allow(Flipper).to receive(:enabled?).with(:mhv_accelerated_delivery_uhd_filtering_enabled,
                                                    user).and_return(true)
          allow(Flipper).to receive(:enabled?).with(:mhv_accelerated_delivery_uhd_ch_enabled, user).and_return(true)
          allow(Flipper).to receive(:enabled?).with(:mhv_accelerated_delivery_uhd_sp_enabled, user).and_return(false)
          allow(Flipper).to receive(:enabled?).with(:mhv_accelerated_delivery_uhd_mb_enabled, user).and_return(false)
          allow(Rails.logger).to receive(:info)
          labs = service.get_labs(start_date: '2024-01-01', end_date: '2025-05-31')
          expect(labs.size).to eq(1)
          expect(labs.first.attributes.test_code).to eq('CH')
        end
      end

      context 'when MB Flipper is enabled' do
        it 'would return MB test codes if present in the data' do
          allow(Flipper).to receive(:enabled?).with(:mhv_accelerated_delivery_uhd_filtering_enabled,
                                                    user).and_return(true)
          allow(Flipper).to receive(:enabled?).with(:mhv_accelerated_delivery_uhd_ch_enabled, user).and_return(false)
          allow(Flipper).to receive(:enabled?).with(:mhv_accelerated_delivery_uhd_sp_enabled, user).and_return(false)
          allow(Flipper).to receive(:enabled?).with(:mhv_accelerated_delivery_uhd_mb_enabled, user).and_return(true)
          allow(Rails.logger).to receive(:info)
          labs = service.get_labs(start_date: '2024-01-01', end_date: '2025-05-31')
          expect(labs.size).to eq(1)
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
    let(:record_mb) { double(attributes: double(test_code: 'MB')) }
    let(:record_other) { double(attributes: double(test_code: 'OTHER')) }
    let(:records) { [record_ch, record_sp, record_mb, record_other] }

    context 'when filtering is disabled' do
      it 'returns all records regardless of individual toggle states' do
        allow(Flipper).to receive(:enabled?).with(:mhv_accelerated_delivery_uhd_filtering_enabled,
                                                  user).and_return(false)
        allow(Flipper).to receive(:enabled?).with(:mhv_accelerated_delivery_uhd_ch_enabled, user).and_return(false)
        allow(Flipper).to receive(:enabled?).with(:mhv_accelerated_delivery_uhd_sp_enabled, user).and_return(false)
        allow(Flipper).to receive(:enabled?).with(:mhv_accelerated_delivery_uhd_mb_enabled, user).and_return(false)
        allow(Rails.logger).to receive(:info)

        result = service.send(:filter_records, records)

        expect(result).to eq(records)
        expect(Rails.logger).to have_received(:info).with(
          hash_including(
            message: 'UHD filtering disabled - returning all records',
            total_records: 4,
            service: 'unified_health_data'
          )
        )
      end
    end

    context 'when filtering is enabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:mhv_accelerated_delivery_uhd_filtering_enabled,
                                                  user).and_return(true)
        allow(Rails.logger).to receive(:info)
      end

      it 'returns only records with enabled Flipper flags' do
        allow(Flipper).to receive(:enabled?).with(:mhv_accelerated_delivery_uhd_ch_enabled, user).and_return(true)
        allow(Flipper).to receive(:enabled?).with(:mhv_accelerated_delivery_uhd_sp_enabled, user).and_return(false)
        allow(Flipper).to receive(:enabled?).with(:mhv_accelerated_delivery_uhd_mb_enabled, user).and_return(true)
        result = service.send(:filter_records, records)
        expect(result).to eq([record_ch, record_mb])
      end

      it 'returns only MB records when only MB flag is enabled' do
        allow(Flipper).to receive(:enabled?).with(:mhv_accelerated_delivery_uhd_ch_enabled, user).and_return(false)
        allow(Flipper).to receive(:enabled?).with(:mhv_accelerated_delivery_uhd_sp_enabled, user).and_return(false)
        allow(Flipper).to receive(:enabled?).with(:mhv_accelerated_delivery_uhd_mb_enabled, user).and_return(true)
        result = service.send(:filter_records, records)
        expect(result).to eq([record_mb])
      end

      it 'returns all supported records when all flags are enabled' do
        allow(Flipper).to receive(:enabled?).with(:mhv_accelerated_delivery_uhd_ch_enabled, user).and_return(true)
        allow(Flipper).to receive(:enabled?).with(:mhv_accelerated_delivery_uhd_sp_enabled, user).and_return(true)
        allow(Flipper).to receive(:enabled?).with(:mhv_accelerated_delivery_uhd_mb_enabled, user).and_return(true)
        result = service.send(:filter_records, records)
        expect(result).to eq([record_ch, record_sp, record_mb])
      end

      it 'filters out unsupported test codes even when all flags are enabled' do
        allow(Flipper).to receive(:enabled?).with(:mhv_accelerated_delivery_uhd_ch_enabled, user).and_return(true)
        allow(Flipper).to receive(:enabled?).with(:mhv_accelerated_delivery_uhd_sp_enabled, user).and_return(true)
        allow(Flipper).to receive(:enabled?).with(:mhv_accelerated_delivery_uhd_mb_enabled, user).and_return(true)
        result = service.send(:filter_records, records)
        expect(result).not_to include(record_other)
      end

      it 'logs filtering statistics' do
        allow(Flipper).to receive(:enabled?).with(:mhv_accelerated_delivery_uhd_ch_enabled, user).and_return(true)
        allow(Flipper).to receive(:enabled?).with(:mhv_accelerated_delivery_uhd_sp_enabled, user).and_return(false)
        allow(Flipper).to receive(:enabled?).with(:mhv_accelerated_delivery_uhd_mb_enabled, user).and_return(true)

        service.send(:filter_records, records)

        expect(Rails.logger).to have_received(:info).with(
          hash_including(
            message: 'UHD filtering enabled - applied test code filtering',
            total_records: 4,
            filtered_records: 2,
            service: 'unified_health_data'
          )
        )
      end
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

    it 'includes the less-than comparator in the text result when present' do
      obs = { 'valueQuantity' => { 'value' => 50, 'comparator' => '<', 'unit' => 'mmol/L' } }
      expect(service.send(:fetch_observation_value, obs)).to eq({ type: 'quantity', text: '<50 mmol/L' })
    end

    it 'includes the greater-than comparator in the text result when present' do
      obs = { 'valueQuantity' => { 'value' => 120, 'comparator' => '>', 'unit' => 'mg/dL' } }
      expect(service.send(:fetch_observation_value, obs)).to eq({ type: 'quantity', text: '>120 mg/dL' })
    end

    it 'includes the less-than-or-equal comparator in the text result when present' do
      obs = { 'valueQuantity' => { 'value' => 6.5, 'comparator' => '<=', 'unit' => '%' } }
      expect(service.send(:fetch_observation_value, obs)).to eq({ type: 'quantity', text: '<=6.5 %' })
    end

    it 'includes the greater-than-or-equal comparator in the text result when present' do
      obs = { 'valueQuantity' => { 'value' => 8.0, 'comparator' => '>=', 'unit' => 'ng/mL' } }
      expect(service.send(:fetch_observation_value, obs)).to eq({ type: 'quantity', text: '>=8.0 ng/mL' })
    end

    it 'includes the "sufficient to achieve" (ad) comparator in the text result when present' do
      obs = { 'valueQuantity' => { 'value' => 12.3, 'comparator' => 'ad', 'unit' => 'mol/L' } }
      expect(service.send(:fetch_observation_value, obs)).to eq({ type: 'quantity', text: 'ad12.3 mol/L' })
    end

    it 'handles valueQuantity with no unit correctly' do
      obs = { 'valueQuantity' => { 'value' => 10, 'comparator' => '>' } }
      expect(service.send(:fetch_observation_value, obs)).to eq({ type: 'quantity', text: '>10' })
    end

    it 'handles empty or nil comparator gracefully' do
      obs = { 'valueQuantity' => { 'value' => 75, 'comparator' => '', 'unit' => 'pg/mL' } }
      expect(service.send(:fetch_observation_value, obs)).to eq({ type: 'quantity', text: '75 pg/mL' })
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
        result = service.send(:fetch_observations, record)
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
        result = service.send(:fetch_observations, record)
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
        result = service.send(:fetch_observations, record)
        expect(result.size).to eq(1)
        expect(result.first.reference_range).to eq('YELLOW, <= 10, >= 1, >= 2, <= 8')
      end
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
    describe '#fetch_combined_records' do
      context 'when body is nil' do
        it 'returns an empty array' do
          result = service.send(:fetch_combined_records, nil)

          expect(result).to eq([])
        end
      end
    end

    describe '#fetch_display' do
      it 'uses code.text if ServiceRequest is not found' do
        record = {
          'resource' => {
            'contained' => [
              { 'resourceType' => 'OtherType' }
            ],
            'code' => { 'text' => 'Fallback Test' }
          }
        }
        expect(service.send(:fetch_display, record)).to eq('Fallback Test')
      end

      it 'returns empty string if neither ServiceRequest nor code.text is present' do
        record = {
          'resource' => {
            'contained' => [
              { 'resourceType' => 'OtherType' }
            ]
          }
        }
        expect(service.send(:fetch_display, record)).to eq('')
      end
    end
  end

  # Clinical Notes
  describe '#get_care_summaries_and_notes' do
    let(:notes_sample_response) do
      JSON.parse(Rails.root.join(
        'spec', 'fixtures', 'unified_health_data', 'notes_sample_response.json'
      ).read)
    end

    let(:notes_no_vista_response) do
      JSON.parse(Rails.root.join(
        'spec', 'fixtures', 'unified_health_data', 'notes_empty_vista_response.json'
      ).read)
    end

    let(:notes_no_oh_response) do
      JSON.parse(Rails.root.join(
        'spec', 'fixtures', 'unified_health_data', 'notes_empty_oh_response.json'
      ).read)
    end

    let(:notes_empty_response) do
      JSON.parse(Rails.root.join(
        'spec', 'fixtures', 'unified_health_data', 'notes_empty_response.json'
      ).read)
    end

    context 'happy path' do
      context 'when data exists for both VistA + OH' do
        it 'returns care summaries and notes' do
          allow(service).to receive_messages(fetch_access_token: 'token', perform: double(body: notes_sample_response),
                                             parse_response_body: notes_sample_response)

          notes = service.get_care_summaries_and_notes
          expect(notes.size).to eq(6)
          expect(notes.map(&:type)).to contain_exactly(
            'physician_procedure_note',
            'physician_procedure_note',
            'consult_result',
            'physician_procedure_note',
            'discharge_summary',
            'other'
          )
          expect(notes).to all(have_attributes(
                                 {
                                   'id' => be_a(String),
                                   'name' => be_a(String),
                                   'type' => be_a(String),
                                   'date' => be_a(String),
                                   'date_signed' => be_a(String).or(be_nil),
                                   'written_by' => be_a(String).or(be_nil),
                                   'signed_by' => be_a(String).or(be_nil),
                                   'location' => be_a(String).or(be_nil),
                                   'note' => be_a(String).or(be_nil)
                                 }
                               ))
        end
      end

      context 'when data exists for only VistA or OH' do
        it 'returns care summaries and notes for VistA only' do
          allow(service).to receive_messages(fetch_access_token: 'token', perform: double(body: notes_no_oh_response),
                                             parse_response_body: notes_no_oh_response)

          notes = service.get_care_summaries_and_notes
          expect(notes.size).to eq(4)
          expect(notes.map(&:type)).to contain_exactly(
            'physician_procedure_note',
            'physician_procedure_note',
            'consult_result',
            'physician_procedure_note'
          )
          expect(notes).to all(have_attributes(
                                 {
                                   'id' => be_a(String),
                                   'name' => be_a(String),
                                   'type' => be_a(String),
                                   'date' => be_a(String),
                                   'date_signed' => be_a(String).or(be_nil),
                                   'written_by' => be_a(String),
                                   'signed_by' => be_a(String).or(be_nil),
                                   'location' => be_a(String).or(be_nil),
                                   'note' => be_a(String).or(be_nil)
                                 }
                               ))
        end

        it 'returns care summaries and notes for OH only' do
          allow(service).to receive_messages(fetch_access_token: 'token',
                                             perform: double(body: notes_no_vista_response),
                                             parse_response_body: notes_no_vista_response)

          notes = service.get_care_summaries_and_notes
          expect(notes.size).to eq(2)
          expect(notes.map(&:type)).to contain_exactly(
            'discharge_summary',
            'other'
          )
          expect(notes).to all(have_attributes(
                                 {
                                   'id' => be_a(String),
                                   'name' => be_a(String),
                                   'type' => be_a(String),
                                   'date' => be_a(String),
                                   'date_signed' => be_a(String).or(be_nil),
                                   'written_by' => be_a(String),
                                   'signed_by' => be_a(String).or(be_nil),
                                   'location' => be_a(String).or(be_nil),
                                   'note' => be_a(String).or(be_nil)
                                 }
                               ))
        end
      end

      context 'when there are no records in VistA or OH' do
        it 'returns care summaries and notes' do
          allow(service).to receive_messages(fetch_access_token: 'token', perform: double(body: notes_empty_response),
                                             parse_response_body: notes_empty_response)

          notes = service.get_care_summaries_and_notes
          expect(notes.size).to eq(0)
        end
      end
    end

    context 'error handling' do
      it 'handles unknown errors' do
        uhd_service = double
        allow(UnifiedHealthData::Service).to receive(:new).with(user).and_return(uhd_service)
        allow(uhd_service).to receive(:get_care_summaries_and_notes).and_raise(StandardError.new('Unknown fetch error'))

        expect do
          uhd_service.get_care_summaries_and_notes
        end.to raise_error(StandardError, 'Unknown fetch error')
      end
    end
  end

  # Prescriptions
  describe '#get_prescriptions' do
    let(:prescriptions_response) do
      JSON.parse(Rails.root.join(
        'spec', 'fixtures', 'unified_health_data', 'prescriptions_response.json'
      ).read)
    end

    context 'with valid prescription responses' do
      before do
        allow(service).to receive_messages(fetch_access_token: 'token',
                                           perform: double(body: prescriptions_response),
                                           parse_response_body: prescriptions_response)
      end

      it 'returns prescriptions from both VistA and Oracle Health' do
        prescriptions = service.get_prescriptions
        expect(prescriptions.size).to eq(5) # 3 VistA + 2 Oracle Health

        # Check that prescriptions are UnifiedHealthData::Prescription objects
        expect(prescriptions).to all(be_a(UnifiedHealthData::Prescription))

        # Verify delegation methods work
        expect(prescriptions.map(&:prescription_id)).to include('28148665', '28148545', '5098027', '15208365735',
                                                                '15209317771')
        expect(prescriptions.map(&:prescription_name)).to include('COAL TAR 2.5% TOP SOLN',
                                                                  'BACITRACIN 500 UNT/GM OPH OINT')
      end

      it 'properly maps VistA prescription fields' do
        prescriptions = service.get_prescriptions
        vista_prescription = prescriptions.find { |p| p.prescription_id == '28148665' }

        expect(vista_prescription.refill_status).to eq('active')
        expect(vista_prescription.refill_remaining).to eq(11)
        expect(vista_prescription.facility_name).to eq('SLC4')
        expect(vista_prescription.prescription_name).to eq('COAL TAR 2.5% TOP SOLN')
        expect(vista_prescription.sig).to eq('APPLY TEASPOONFUL(S) TO THE AFFECTED AREA EVERY DAY')
        expect(vista_prescription.refillable?).to be true
        expect(vista_prescription.station_number).to eq('991')
        expect(vista_prescription.prescription_number).to eq('3636485')
      end

      it 'properly maps Oracle Health prescription fields' do
        prescriptions = service.get_prescriptions
        oracle_prescription = prescriptions.find { |p| p.prescription_id == '15208365735' }

        expect(oracle_prescription.refill_status).to eq('active')
        expect(oracle_prescription.refill_remaining).to eq(0)
        expect(oracle_prescription.prescription_name).to eq('amLODIPine (amLODIPine 5 mg tablet)')
        expect(oracle_prescription.sig).to eq('See Instructions, daily, 1 EA, 0 Refill(s)')
        expect(oracle_prescription.refillable?).to be false # 0 refills remaining
        expect(oracle_prescription.ordered_date).to eq('2025-01-29T19:41:43Z')
      end

      it 'handles different refill statuses correctly' do
        prescriptions = service.get_prescriptions

        active_prescription = prescriptions.find { |p| p.prescription_id == '28148665' }
        submitted_prescription = prescriptions.find { |p| p.prescription_id == '28148545' }
        expired_prescription = prescriptions.find { |p| p.prescription_id == '5098027' }

        expect(active_prescription.refill_status).to eq('active')
        expect(submitted_prescription.refill_status).to eq('submitted')
        expect(expired_prescription.refill_status).to eq('expired')
      end

      it 'logs prescription retrieval information' do
        allow(Rails.logger).to receive(:info)

        service.get_prescriptions

        expect(Rails.logger).to have_received(:info).with(
          hash_including(
            message: 'UHD prescriptions retrieved',
            total_prescriptions: 5,
            service: 'unified_health_data'
          )
        )
      end
    end

    context 'with malformed response' do
      before do
        allow(service).to receive_messages(fetch_access_token: 'token', perform: double(body: nil))
      end

      it 'handles gracefully' do
        allow(service).to receive(:parse_response_body).and_return(nil)
        expect { service.get_prescriptions }.not_to raise_error
      end

      it 'returns empty array for nil response' do
        allow(service).to receive(:parse_response_body).and_return(nil)
        result = service.get_prescriptions
        expect(result).to eq([])
      end
    end

    context 'with partial data' do
      let(:vista_only_response) do
        {
          'vista' => prescriptions_response['vista'],
          'oracle-health' => nil
        }
      end

      let(:oracle_only_response) do
        {
          'vista' => nil,
          'oracle-health' => prescriptions_response['oracle-health']
        }
      end

      it 'handles VistA-only data' do
        allow(service).to receive_messages(fetch_access_token: 'token',
                                           perform: double(body: vista_only_response),
                                           parse_response_body: vista_only_response)

        prescriptions = service.get_prescriptions
        expect(prescriptions.size).to eq(3)
        expect(prescriptions.map(&:prescription_id)).to contain_exactly('28148665', '28148545', '5098027')
      end

      it 'handles Oracle Health-only data' do
        allow(service).to receive_messages(fetch_access_token: 'token',
                                           perform: double(body: oracle_only_response),
                                           parse_response_body: oracle_only_response)

        prescriptions = service.get_prescriptions
        expect(prescriptions.size).to eq(2)
        expect(prescriptions.map(&:prescription_id)).to contain_exactly('15208365735', '15209317771')
      end
    end
  end

  describe '#refill_prescription' do
    let(:refill_response) do
      JSON.parse(Rails.root.join(
        'spec', 'fixtures', 'unified_health_data', 'refill_response.json'
      ).read)
    end

    context 'with valid refill request' do
      before do
        allow(service).to receive_messages(fetch_access_token: 'token',
                                           perform: double(body: refill_response, status: 200),
                                           parse_response_body: refill_response)
      end

      it 'submits refill requests and returns success/failure breakdown' do
        prescription_ids = %w[28148665 28148545]
        result = service.refill_prescription(prescription_ids)

        expect(result).to have_key(:success)
        expect(result).to have_key(:failed)

        expect(result[:success]).to contain_exactly(
          { id: '28148665', status: 'submitted' }
        )

        expect(result[:failed]).to contain_exactly(
          { id: '28148545', error: 'Prescription already has pending refill request' }
        )
      end

      it 'formats request body correctly' do
        prescription_ids = %w[12345 67890]
        expected_body = {
          prescriptions: [
            { orderId: '12345' },
            { orderId: '67890' }
          ]
        }.to_json

        expect(service).to receive(:perform).with(
          :post,
          anything,
          expected_body,
          hash_including('Content-Type' => 'application/json')
        ).and_return(double(body: refill_response))

        service.refill_prescription(prescription_ids)
      end
    end

    context 'with service errors' do
      it 'handles network errors gracefully' do
        allow(service).to receive(:fetch_access_token).and_raise(StandardError.new('Network error'))

        prescription_ids = ['12345']
        result = service.refill_prescription(prescription_ids)

        expect(result[:success]).to eq([])
        expect(result[:failed]).to contain_exactly(
          { id: '12345', error: 'Service unavailable' }
        )
      end

      it 'logs error when refill fails' do
        allow(service).to receive(:fetch_access_token).and_raise(StandardError.new('API error'))
        allow(Rails.logger).to receive(:error)

        service.refill_prescription(['12345'])

        expect(Rails.logger).to have_received(:error).with('Error submitting prescription refill: API error')
      end
    end

    context 'with malformed response' do
      before do
        allow(service).to receive_messages(fetch_access_token: 'token',
                                           perform: double(body: '{}'),
                                           parse_response_body: {})
      end

      it 'handles empty response gracefully' do
        result = service.refill_prescription(['12345'])

        expect(result[:success]).to eq([])
        expect(result[:failed]).to eq([])
      end
    end
  end
end
