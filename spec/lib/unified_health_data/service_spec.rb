# frozen_string_literal: true

require 'rails_helper'
require 'unified_health_data/service'

describe UnifiedHealthData::Service, type: :service do
  subject { described_class }

  let(:user) { build(:user, :loa3, icn: '1000123456V123456') }
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
          expect(labs.map(&:test_code)).to contain_exactly('CH', 'SP', 'MB')
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
          expect(labs.map(&:test_code)).to contain_exactly('CH', 'SP', 'MB')
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
          expect(labs.first.test_code).to eq('CH')
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
    let(:record_ch) { double(test_code: 'CH') }
    let(:record_sp) { double(test_code: 'SP') }
    let(:record_mb) { double(test_code: 'MB') }
    let(:record_other) { double(test_code: 'OTHER') }
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

  # describe '#fetch_location' do
  #   it 'returns the organization name if present' do
  #     record = { 'resource' => { 'contained' => [{ 'resourceType' => 'Organization', 'name' => 'LabX' }] } }
  #     expect(service.send(:fetch_location, record)).to eq('LabX')
  #   end

  #   it 'returns nil if no organization' do
  #     record = { 'resource' => { 'contained' => [{ 'resourceType' => 'Other' }] } }
  #     expect(service.send(:fetch_location, record)).to be_nil
  #   end
  # end

  # describe '#fetch_ordered_by' do
  #   it 'returns practitioner full name if present' do
  #     record = { 'resource' => { 'contained' => [{ 'resourceType' => 'Practitioner',
  #                                                  'name' => [{ 'given' => ['A'], 'family' => 'B' }] }] } }
  #     expect(service.send(:fetch_ordered_by, record)).to eq('A B')
  #   end

  #   it 'returns nil if no practitioner' do
  #     record = { 'resource' => { 'contained' => [{ 'resourceType' => 'Other' }] } }
  #     expect(service.send(:fetch_ordered_by, record)).to be_nil
  #   end
  # end

  # describe '#fetch_observation_value' do
  #   it 'returns quantity type and text' do
  #     obs = { 'valueQuantity' => { 'value' => 5, 'unit' => 'mg' } }
  #     expect(service.send(:fetch_observation_value, obs)).to eq({ type: 'quantity', text: '5 mg' })
  #   end

  #   it 'includes the less-than comparator in the text result when present' do
  #     obs = { 'valueQuantity' => { 'value' => 50, 'comparator' => '<', 'unit' => 'mmol/L' } }
  #     expect(service.send(:fetch_observation_value, obs)).to eq({ type: 'quantity', text: '<50 mmol/L' })
  #   end

  #   it 'includes the greater-than comparator in the text result when present' do
  #     obs = { 'valueQuantity' => { 'value' => 120, 'comparator' => '>', 'unit' => 'mg/dL' } }
  #     expect(service.send(:fetch_observation_value, obs)).to eq({ type: 'quantity', text: '>120 mg/dL' })
  #   end

  #   it 'includes the less-than-or-equal comparator in the text result when present' do
  #     obs = { 'valueQuantity' => { 'value' => 6.5, 'comparator' => '<=', 'unit' => '%' } }
  #     expect(service.send(:fetch_observation_value, obs)).to eq({ type: 'quantity', text: '<=6.5 %' })
  #   end

  #   it 'includes the greater-than-or-equal comparator in the text result when present' do
  #     obs = { 'valueQuantity' => { 'value' => 8.0, 'comparator' => '>=', 'unit' => 'ng/mL' } }
  #     expect(service.send(:fetch_observation_value, obs)).to eq({ type: 'quantity', text: '>=8.0 ng/mL' })
  #   end

  #   it 'includes the "sufficient to achieve" (ad) comparator in the text result when present' do
  #     obs = { 'valueQuantity' => { 'value' => 12.3, 'comparator' => 'ad', 'unit' => 'mol/L' } }
  #     expect(service.send(:fetch_observation_value, obs)).to eq({ type: 'quantity', text: 'ad12.3 mol/L' })
  #   end

  #   it 'handles valueQuantity with no unit correctly' do
  #     obs = { 'valueQuantity' => { 'value' => 10, 'comparator' => '>' } }
  #     expect(service.send(:fetch_observation_value, obs)).to eq({ type: 'quantity', text: '>10' })
  #   end

  #   it 'handles empty or nil comparator gracefully' do
  #     obs = { 'valueQuantity' => { 'value' => 75, 'comparator' => '', 'unit' => 'pg/mL' } }
  #     expect(service.send(:fetch_observation_value, obs)).to eq({ type: 'quantity', text: '75 pg/mL' })
  #   end

  #   it 'returns codeable-concept type and text' do
  #     obs = { 'valueCodeableConcept' => { 'text' => 'POS' } }
  #     expect(service.send(:fetch_observation_value, obs)).to eq({ type: 'codeable-concept', text: 'POS' })
  #   end

  #   it 'returns string type and text' do
  #     obs = { 'valueString' => 'abc' }
  #     expect(service.send(:fetch_observation_value, obs)).to eq({ type: 'string', text: 'abc' })
  #   end

  #   it 'returns date-time type and text' do
  #     obs = { 'valueDateTime' => '2024-06-01T00:00:00Z' }
  #     expect(service.send(:fetch_observation_value, obs)).to eq({ type: 'date-time', text: '2024-06-01T00:00:00Z' })
  #   end

  #   it 'returns nils for unsupported types' do
  #     obs = {}
  #     expect(service.send(:fetch_observation_value, obs)).to eq({ type: nil, text: nil })
  #   end
  # end

  # describe '#fetch_body_site' do
  #   context 'when contained is nil' do
  #     it 'returns an empty string' do
  #       resource = { 'basedOn' => [{ 'reference' => 'ServiceRequest/123' }] }
  #       contained = nil

  #       result = service.send(:fetch_body_site, resource, contained)

  #       expect(result).to eq('')
  #     end
  #   end

  #   context 'when basedOn is nil' do
  #     it 'returns an empty string' do
  #       resource = {}
  #       contained = [{ 'resourceType' => 'ServiceRequest', 'id' => '123' }]

  #       result = service.send(:fetch_body_site, resource, contained)

  #       expect(result).to eq('')
  #     end
  #   end
  # end

  # describe '#fetch_sample_tested' do
  #   context 'when contained is nil' do
  #     it 'returns an empty string' do
  #       record = { 'specimen' => { 'reference' => 'Specimen/123' } }
  #       contained = nil

  #       result = service.send(:fetch_sample_tested, record, contained)

  #       expect(result).to eq('')
  #     end
  #   end

  #   context 'when specimen is nil' do
  #     it 'returns an empty string' do
  #       record = {}
  #       contained = [{ 'resourceType' => 'Specimen', 'id' => '123' }]

  #       result = service.send(:fetch_sample_tested, record, contained)

  #       expect(result).to eq('')
  #     end
  #   end
  # end

  # describe '#fetch_observations' do
  #   context 'when contained is nil' do
  #     it 'returns an empty array' do
  #       record = { 'resource' => { 'contained' => nil } }

  #       result = service.send(:fetch_observations, record)

  #       expect(result).to eq([])
  #     end
  #   end

  #   context 'with reference ranges' do
  #     it 'returns observations with a single reference range' do
  #       record = {
  #         'resource' => {
  #           'contained' => [
  #             {
  #               'resourceType' => 'Observation',
  #               'code' => { 'text' => 'Glucose' },
  #               'valueQuantity' => { 'value' => 100, 'unit' => 'mg/dL' },
  #               'referenceRange' => [
  #                 { 'text' => '70-110 mg/dL' }
  #               ],
  #               'status' => 'final',
  #               'note' => [{ 'text' => 'Normal' }]
  #             }
  #           ]
  #         }
  #       }
  #       result = service.send(:fetch_observations, record)
  #       expect(result.size).to eq(1)
  #       expect(result.first.reference_range).to eq('70-110 mg/dL')
  #     end

  #     it 'returns observations with multiple reference ranges joined' do
  #       record = {
  #         'resource' => {
  #           'contained' => [
  #             {
  #               'resourceType' => 'Observation',
  #               'code' => { 'text' => 'Calcium' },
  #               'valueQuantity' => { 'value' => 9.5, 'unit' => 'mg/dL' },
  #               'referenceRange' => [
  #                 { 'text' => '8.5-10.5 mg/dL' },
  #                 { 'text' => 'Lab-specific: 9-11 mg/dL' }
  #               ],
  #               'status' => 'final',
  #               'note' => [{ 'text' => 'Within range' }]
  #             }
  #           ]
  #         }
  #       }
  #       result = service.send(:fetch_observations, record)
  #       expect(result.size).to eq(1)
  #       expect(result.first.reference_range).to eq('8.5-10.5 mg/dL, Lab-specific: 9-11 mg/dL')
  #     end

  #     it 'returns observations with low/high values in reference range' do
  #       record = {
  #         'resource' => {
  #           'contained' => [
  #             {
  #               'resourceType' => 'Observation',
  #               'code' => { 'text' => 'TSH' },
  #               'valueQuantity' => { 'value' => 1.8, 'unit' => 'mIU/L' },
  #               'referenceRange' => [
  #                 {
  #                   'low' => {
  #                     'value' => 0.7,
  #                     'unit' => 'mIU/L'
  #                   },
  #                   'high' => {
  #                     'value' => 4.5,
  #                     'unit' => 'mIU/L'
  #                   },
  #                   'type' => {
  #                     'coding' => [
  #                       {
  #                         'system' => 'http://terminology.hl7.org/CodeSystem/referencerange-meaning',
  #                         'code' => 'normal',
  #                         'display' => 'Normal Range'
  #                       }
  #                     ],
  #                     'text' => 'Normal Range'
  #                   }
  #                 }
  #               ],
  #               'status' => 'final',
  #               'note' => [{ 'text' => 'Within normal limits' }]
  #             }
  #           ]
  #         }
  #       }
  #       result = service.send(:fetch_observations, record)
  #       expect(result.size).to eq(1)
  #       expect(result.first.reference_range).to eq('Normal Range: 0.7 - 4.5 mIU/L')
  #     end

  #     it 'returns observations with multiple low/high reference ranges joined' do
  #       record = {
  #         'resource' => {
  #           'contained' => [
  #             {
  #               'resourceType' => 'Observation',
  #               'code' => { 'text' => 'Comprehensive Metabolic Panel' },
  #               'valueQuantity' => { 'value' => 1.8, 'unit' => 'mIU/L' },
  #               'referenceRange' => [
  #                 {
  #                   'low' => {
  #                     'value' => 0.7,
  #                     'unit' => 'mIU/L'
  #                   },
  #                   'high' => {
  #                     'value' => 4.5,
  #                     'unit' => 'mIU/L'
  #                   },
  #                   'type' => {
  #                     'coding' => [
  #                       {
  #                         'system' => 'http://terminology.hl7.org/CodeSystem/referencerange-meaning',
  #                         'code' => 'normal',
  #                         'display' => 'Normal Range'
  #                       }
  #                     ],
  #                     'text' => 'Normal Range'
  #                   }
  #                 },
  #                 {
  #                   'low' => {
  #                     'value' => 0.5,
  #                     'unit' => 'mIU/L'
  #                   },
  #                   'high' => {
  #                     'value' => 5.0,
  #                     'unit' => 'mIU/L'
  #                   },
  #                   'type' => {
  #                     'coding' => [
  #                       {
  #                         'system' => 'http://terminology.hl7.org/CodeSystem/referencerange-meaning',
  #                         'code' => 'treatment',
  #                         'display' => 'Treatment Range'
  #                       }
  #                     ],
  #                     'text' => 'Treatment Range'
  #                   }
  #                 }
  #               ],
  #               'status' => 'final',
  #               'note' => [{ 'text' => 'Multiple reference ranges' }]
  #             }
  #           ]
  #         }
  #       }
  #       result = service.send(:fetch_observations, record)
  #       expect(result.size).to eq(1)
  #       expect(result.first.reference_range).to eq(
  #         'Normal Range: 0.7 - 4.5 mIU/L, ' \
  #         'Treatment Range: 0.5 - 5.0 mIU/L'
  #       )
  #     end

  #     it 'returns empty string for reference range if not present' do
  #       record = {
  #         'resource' => {
  #           'contained' => [
  #             {
  #               'resourceType' => 'Observation',
  #               'code' => { 'text' => 'Sodium' },
  #               'valueQuantity' => { 'value' => 140, 'unit' => 'mmol/L' },
  #               'status' => 'final',
  #               'note' => [{ 'text' => 'Normal' }]
  #             }
  #           ]
  #         }
  #       }
  #       result = service.send(:fetch_observations, record)
  #       expect(result.size).to eq(1)
  #       expect(result.first.reference_range).to eq('')
  #     end

  #     it 'returns observations with only low value in reference range' do
  #       record = {
  #         'resource' => {
  #           'contained' => [
  #             {
  #               'resourceType' => 'Observation',
  #               'code' => { 'text' => 'Oxygen Saturation' },
  #               'valueQuantity' => { 'value' => 96, 'unit' => '%' },
  #               'referenceRange' => [
  #                 {
  #                   'low' => {
  #                     'value' => 94,
  #                     'unit' => '%'
  #                   },
  #                   'type' => {
  #                     'coding' => [
  #                       {
  #                         'system' => 'http://terminology.hl7.org/CodeSystem/referencerange-meaning',
  #                         'code' => 'normal',
  #                         'display' => 'Normal Range'
  #                       }
  #                     ],
  #                     'text' => 'Normal Range'
  #                   }
  #                 }
  #               ],
  #               'status' => 'final',
  #               'note' => [{ 'text' => 'Above minimum threshold' }]
  #             }
  #           ]
  #         }
  #       }
  #       result = service.send(:fetch_observations, record)
  #       expect(result.size).to eq(1)
  #       expect(result.first.reference_range).to eq('Normal Range: >= 94 %')
  #     end

  #     it 'returns observations with only high value in reference range' do
  #       record = {
  #         'resource' => {
  #           'contained' => [
  #             {
  #               'resourceType' => 'Observation',
  #               'code' => { 'text' => 'Blood Glucose' },
  #               'valueQuantity' => { 'value' => 105, 'unit' => 'mg/dL' },
  #               'referenceRange' => [
  #                 {
  #                   'high' => {
  #                     'value' => 120,
  #                     'unit' => 'mg/dL'
  #                   },
  #                   'type' => {
  #                     'coding' => [
  #                       {
  #                         'system' => 'http://terminology.hl7.org/CodeSystem/referencerange-meaning',
  #                         'code' => 'normal',
  #                         'display' => 'Normal Range'
  #                       }
  #                     ],
  #                     'text' => 'Normal Range'
  #                   }
  #                 }
  #               ],
  #               'status' => 'final',
  #               'note' => [{ 'text' => 'Below maximum threshold' }]
  #             }
  #           ]
  #         }
  #       }
  #       result = service.send(:fetch_observations, record)
  #       expect(result.size).to eq(1)
  #       expect(result.first.reference_range).to eq('Normal Range: <= 120 mg/dL')
  #     end

  #     it 'handles mixed reference range formats correctly' do
  #       record = {
  #         'resource' => {
  #           'contained' => [
  #             {
  #               'resourceType' => 'Observation',
  #               'code' => { 'text' => 'Mixed Format Test' },
  #               'valueQuantity' => { 'value' => 5, 'unit' => 'units' },
  #               'referenceRange' => [
  #                 { 'text' => 'YELLOW' },
  #                 {
  #                   'high' => { 'value' => 10 }
  #                 },
  #                 {
  #                   'low' => { 'value' => 1 }
  #                 },
  #                 {
  #                   'low' => { 'value' => 2 }
  #                 },
  #                 {
  #                   'high' => { 'value' => 8 }
  #                 }
  #               ],
  #               'status' => 'final'
  #             }
  #           ]
  #         }
  #       }
  #       result = service.send(:fetch_observations, record)
  #       expect(result.size).to eq(1)
  #       expect(result.first.reference_range).to eq('YELLOW, <= 10, >= 1, >= 2, <= 8')
  #     end
  #   end
  # end

  # describe '#fetch_code' do
  #   context 'when category is nil' do
  #     it 'returns nil' do
  #       record = { 'resource' => { 'category' => nil } }

  #       result = service.send(:fetch_code, record)

  #       expect(result).to be_nil
  #     end
  #   end

  #   context 'when category is empty' do
  #     it 'returns nil' do
  #       record = { 'resource' => { 'category' => [] } }

  #       result = service.send(:fetch_code, record)

  #       expect(result).to be_nil
  #     end
  #   end
  # end

  # describe '#parse_single_record' do
  #   context 'when record is nil' do
  #     it 'returns nil' do
  #       result = service.send(:parse_single_record, nil)

  #       expect(result).to be_nil
  #     end
  #   end

  #   context 'when resource is nil' do
  #     it 'returns nil' do
  #       record = {}

  #       result = service.send(:parse_single_record, record)

  #       expect(result).to be_nil
  #     end
  #   end
  # end

  # describe '#parse_labs' do
  #   context 'when records is nil' do
  #     it 'returns an empty array' do
  #       result = service.send(:parse_labs, nil)

  #       expect(result).to eq([])
  #     end
  #   end

  #   context 'when records is empty' do
  #     it 'returns an empty array' do
  #       result = service.send(:parse_labs, [])

  #       expect(result).to eq([])
  #     end
  #   end
  # end

  describe '#fetch_combined_records' do
    context 'when body is nil' do
      it 'returns an empty array' do
        result = service.send(:fetch_combined_records, nil)

        expect(result).to eq([])
      end
    end
  end

  #   describe '#fetch_display' do
  #     it 'uses code.text if ServiceRequest is not found' do
  #       record = {
  #         'resource' => {
  #           'contained' => [
  #             { 'resourceType' => 'OtherType' }
  #           ],
  #           'code' => { 'text' => 'Fallback Test' }
  #         }
  #       }
  #       expect(service.send(:fetch_display, record)).to eq('Fallback Test')
  #     end

  #     it 'returns empty string if neither ServiceRequest nor code.text is present' do
  #       record = {
  #         'resource' => {
  #           'contained' => [
  #             { 'resourceType' => 'OtherType' }
  #           ]
  #         }
  #       }
  #       expect(service.send(:fetch_display, record)).to eq('')
  #     end
  #   end

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
          expect(notes.map(&:note_type)).to contain_exactly(
            'physician_procedure_note',
            'physician_procedure_note',
            'consult_result',
            'physician_procedure_note',
            'discharge_summary',
            'other'
          )
          expect(notes[0]).to have_attributes(
            {
              'id' => '76ad925b-0c2c-4401-ac0a-13542d6b6ef5',
              'name' => 'CARE COORDINATION HOME TELEHEALTH DISCHARGE NOTE',
              'loinc_codes' => ['11506-3'],
              'note_type' => 'physician_procedure_note',
              'date' => '2025-01-14T09:18:00.000+00:00',
              'date_signed' => '2025-01-14T09:29:26+00:00',
              'written_by' => 'MARCI P MCGUIRE',
              'signed_by' => 'MARCI P MCGUIRE',
              'admission_date' => nil,
              'discharge_date' => nil,
              'location' => 'CHYSHR TEST LAB',
              'note' => /VGhpcyBpcyBhIHRlc3QgdGVsZWhlYWx0aCBka/i
            }
          )
          expect(notes).to all(have_attributes(
                                 {
                                   'id' => be_a(String),
                                   'name' => be_a(String),
                                   'note_type' => be_a(String),
                                   'loinc_codes' => be_an(Array),
                                   'date' => be_a(String),
                                   'date_signed' => be_a(String).or(be_nil),
                                   'written_by' => be_a(String),
                                   'signed_by' => be_a(String),
                                   'admission_date' => be_a(String).or(be_nil),
                                   'discharge_date' => be_a(String).or(be_nil),
                                   'location' => be_a(String),
                                   'note' => be_a(String)
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
          expect(notes.map(&:note_type)).to contain_exactly(
            'physician_procedure_note',
            'physician_procedure_note',
            'consult_result',
            'physician_procedure_note'
          )
          expect(notes).to all(have_attributes(
                                 {
                                   'id' => be_a(String),
                                   'name' => be_a(String),
                                   'note_type' => be_a(String),
                                   'loinc_codes' => be_an(Array),
                                   'date' => be_a(String),
                                   'date_signed' => be_a(String).or(be_nil),
                                   'written_by' => be_a(String),
                                   'signed_by' => be_a(String),
                                   'admission_date' => be_a(String).or(be_nil),
                                   'discharge_date' => be_a(String).or(be_nil),
                                   'location' => be_a(String),
                                   'note' => be_a(String)
                                 }
                               ))
        end

        it 'returns care summaries and notes for OH only' do
          allow(service).to receive_messages(fetch_access_token: 'token',
                                             perform: double(body: notes_no_vista_response),
                                             parse_response_body: notes_no_vista_response)

          notes = service.get_care_summaries_and_notes
          expect(notes.size).to eq(2)
          expect(notes.map(&:note_type)).to contain_exactly(
            'discharge_summary',
            'other'
          )
          expect(notes).to all(have_attributes(
                                 {
                                   'id' => be_a(String),
                                   'name' => be_a(String),
                                   'note_type' => be_a(String),
                                   'loinc_codes' => be_an(Array),
                                   'date' => be_a(String),
                                   'date_signed' => be_a(String).or(be_nil),
                                   'written_by' => be_a(String),
                                   'signed_by' => be_a(String),
                                   'admission_date' => be_a(String).or(be_nil),
                                   'discharge_date' => be_a(String).or(be_nil),
                                   'location' => be_a(String),
                                   'note' => be_a(String)
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
    context 'with valid prescription responses', :vcr do
      it 'returns prescriptions from both VistA and Oracle Health' do
        VCR.use_cassette('unified_health_data/get_prescriptions_success') do
          prescriptions = service.get_prescriptions
          expect(prescriptions.size).to eq(78)

          # Check that prescriptions are UnifiedHealthData::Prescription objects
          expect(prescriptions).to all(be_a(UnifiedHealthData::Prescription))

          # Verify delegation methods work
          expect(prescriptions.map(&:prescription_id)).to include('25809921', '26058413', '26046248', '15214174591',
                                                                  '15215168033', '15216187241')
          expect(prescriptions.map(&:prescription_name)).to include('ezetimibe 10 MG Oral Tablet',
                                                                    'Sertraline 25 MG Oral Tablet')
        end
      end

      it 'properly maps VistA prescription fields' do
        VCR.use_cassette('unified_health_data/get_prescriptions_success') do
          prescriptions = service.get_prescriptions
          vista_prescription = prescriptions.find { |p| p.prescription_id == '25804851' }

          expect(vista_prescription.refill_status).to eq('activeParked')
          expect(vista_prescription.refill_remaining).to eq(2)
          expect(vista_prescription.facility_name).to eq('DAYT29')
          expect(vista_prescription.prescription_name).to eq('BACITRACIN 500 UNIT/GM OINT 30GM')
          expect(vista_prescription.sig).to eq('APPLY SMALL AMOUNT TO AFFECTED AREA WEEKLY FOR 30 DAYS')
          expect(vista_prescription.refillable?).to be true
          expect(vista_prescription.station_number).to eq('989')
          expect(vista_prescription.prescription_number).to eq('2721174')
        end
      end

      it 'properly maps Oracle Health prescription fields' do
        VCR.use_cassette('unified_health_data/get_prescriptions_success') do
          prescriptions = service.get_prescriptions
          oracle_prescription = prescriptions.find { |p| p.prescription_id == '25809921' }

          expect(oracle_prescription.refill_status).to eq('active')
          expect(oracle_prescription.refill_remaining).to eq(5)
          expect(oracle_prescription.prescription_name).to eq('1.5 ML Buprenorphine 200 MG/ML Prefilled Syringe')
          expect(oracle_prescription.sig).to eq(
            'See Instructions. This should not be dispensed to the patient but should be dispensed to clinic for ' \
            'in-clinic administration.. Refills: 5.'
          )
          expect(oracle_prescription.refillable?).to be false
          expect(oracle_prescription.ordered_date).to eq('Fri, 27 Jun 2025 00:00:00 EDT')
        end
      end

      it 'handles different refill statuses correctly' do
        VCR.use_cassette('unified_health_data/get_prescriptions_success') do
          prescriptions = service.get_prescriptions

          active_prescription = prescriptions.find { |p| p.prescription_id == '25804853' }
          discontinued_prescription = prescriptions.find { |p| p.prescription_id == '25804854' }
          expired_prescription = prescriptions.find { |p| p.prescription_id == '25804855' }

          expect(active_prescription.refill_status).to eq('active')
          expect(discontinued_prescription.refill_status).to eq('discontinued')
          expect(expired_prescription.refill_status).to eq('expired')
        end
      end

      it 'properly handles Oracle Health FHIR features' do
        VCR.use_cassette('unified_health_data/get_prescriptions_success') do
          prescriptions = service.get_prescriptions

          # Test prescription with patientInstruction (should prefer over text)
          oracle_prescription_with_patient_instruction = prescriptions.find { |p| p.prescription_id == '15214174591' }
          expect(oracle_prescription_with_patient_instruction.sig).to eq(
            '2 Inhalation Inhalation (breathe in) every 4 hours as needed shortness of breath or wheezing. ' \
            'Refills: 2.'
          )
          expect(oracle_prescription_with_patient_instruction.facility_name).to eq('Ambulatory Pharmacy')
          expect(oracle_prescription_with_patient_instruction.dispensed_date).to eq('2025-06-24T21:05:53.000Z')

          # Test prescription with completed status mapping
          completed_prescription = prescriptions.find { |p| p.prescription_id == '15214166467' }
          expect(completed_prescription.refill_status).to eq('completed')
          expect(completed_prescription.refillable?).to be false
          expect(completed_prescription.refill_date).to eq('2025-05-22T21:03:45Z')
        end
      end

      it 'logs prescription retrieval information' do
        allow(Rails.logger).to receive(:info)

        VCR.use_cassette('unified_health_data/get_prescriptions_success') do
          service.get_prescriptions

          expect(Rails.logger).to have_received(:info).with(
            hash_including(
              message: 'UHD prescriptions retrieved',
              total_prescriptions: 78,
              service: 'unified_health_data'
            )
          )
        end
      end
    end

    context 'with empty response', :vcr do
      it 'returns empty array for nil response' do
        VCR.use_cassette('unified_health_data/get_prescriptions_empty') do
          result = service.get_prescriptions
          expect(result).to eq([])
        end
      end
    end

    context 'with partial data', :vcr do
      it 'handles VistA-only data' do
        VCR.use_cassette('unified_health_data/get_prescriptions_vista_only') do
          prescriptions = service.get_prescriptions
          expect(prescriptions.size).to eq(33)
          expect(prescriptions.map(&:prescription_id)).to contain_exactly(
            '25804851', '25804852', '25804853', '25804854', '25804855', '25804856', '25804858', '25804859',
            '25804860', '25806260', '25804815', '25804816', '25804820', '25804822', '25804825', '25804826',
            '25804828', '25804831', '25804832', '25804834', '25804836', '25804837', '25804841', '25804842',
            '25804843', '25804844', '25804848', '25893955', '25859533', '25859534', '25809921', '26058413',
            '26046248'
          )
        end
      end

      it 'handles Oracle Health-only data' do
        VCR.use_cassette('unified_health_data/get_prescriptions_oracle_only') do
          prescriptions = service.get_prescriptions
          expect(prescriptions.size).to eq(45)
          expect(prescriptions.map(&:prescription_id)).to contain_exactly(
            '15214174591', '15215168033', '15216187241', '15215488543', '15214174423', '15215979885',
            '15214174571', '15214777121', '15213998699', '15218955729', '15214535999', '15214303643',
            '15214282441', '15215168043', '15213978785', '15214275861', '15214834723', '15215721639',
            '15217757747', '15215020709', '15215098309', '15214174531', '15217281719', '15217757751',
            '15217757667', '15218953273', '15218953219', '15217150277', '15216346305', '15213978755',
            '15215109331', '15215017281', '15215582133', '15215017959', '15214166465', '15214174425',
            '15214282323', '15214661111', '15214282321', '15214174561', '15214174537', '15214192877',
            '15214103419', '15213928373', '15214166467'
          )
        end
      end
    end
  end

  describe '#refill_prescription' do
    context 'with valid refill request', :vcr do
      it 'submits refill requests and returns success/failure breakdown' do
        VCR.use_cassette('unified_health_data/refill_prescription_success') do
          orders = [
            { id: '15220389459', stationNumber: '556' },
            { id: '0000000000001', stationNumber: '570' }
          ]
          result = service.refill_prescription(orders)

          expect(result).to have_key(:success)
          expect(result).to have_key(:failed)

          expect(result[:success]).to contain_exactly(
            { id: '15220389459', status: 'Already in Queue', station_number: '556' }
          )

          expect(result[:failed]).to contain_exactly(
            { id: '0000000000001', error: 'Prescription is not Found', station_number: '570' }
          )
        end
      end

      it 'formats request body correctly' do
        VCR.use_cassette('unified_health_data/refill_prescription_success') do
          orders = [
            { id: '12345', stationNumber: '570' },
            { id: '67890', stationNumber: '556' }
          ]
          expected_body = {
            patientId: user.icn,
            orders: [
              { orderId: '12345', stationNumber: '570' },
              { orderId: '67890', stationNumber: '556' }
            ]
          }.to_json

          expect(service).to receive(:perform).with(
            :post,
            anything,
            expected_body,
            hash_including('Content-Type' => 'application/json')
          ).and_call_original

          service.refill_prescription(orders)
        end
      end
    end

    context 'with service errors' do
      it 'handles network errors gracefully' do
        allow(service).to receive(:fetch_access_token).and_raise(StandardError.new('Network error'))

        orders = [{ id: '12345', stationNumber: '570' }]
        result = service.refill_prescription(orders)

        expect(result[:success]).to eq([])
        expect(result[:failed]).to contain_exactly(
          { id: '12345', error: 'Service unavailable', station_number: '570' }
        )
      end

      it 'logs error when refill fails' do
        allow(service).to receive(:fetch_access_token).and_raise(StandardError.new('API error'))
        allow(Rails.logger).to receive(:error)

        service.refill_prescription([{ id: '12345', stationNumber: '570' }])

        expect(Rails.logger).to have_received(:error).with('Error submitting prescription refill: API error')
      end
    end

    context 'with malformed response', :vcr do
      it 'handles empty response gracefully' do
        VCR.use_cassette('unified_health_data/refill_prescription_empty') do
          result = service.refill_prescription([{ id: '12345', stationNumber: '570' }])

          expect(result[:success]).to eq([])
          expect(result[:failed]).to eq([])
        end
      end
    end
  end

  describe '#get_single_summary_or_note' do
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

          note = service.get_single_summary_or_note('76ad925b-0c2c-4401-ac0a-13542d6b6ef5')
          expect(note).to have_attributes(
            {
              'id' => '76ad925b-0c2c-4401-ac0a-13542d6b6ef5',
              'name' => 'CARE COORDINATION HOME TELEHEALTH DISCHARGE NOTE',
              'loinc_codes' => ['11506-3'],
              'note_type' => 'physician_procedure_note',
              'date' => '2025-01-14T09:18:00.000+00:00',
              'date_signed' => '2025-01-14T09:29:26+00:00',
              'written_by' => 'MARCI P MCGUIRE',
              'signed_by' => 'MARCI P MCGUIRE',
              'admission_date' => nil,
              'discharge_date' => nil,
              'location' => 'CHYSHR TEST LAB',
              'note' => /VGhpcyBpcyBhIHRlc3QgdGVsZWhlYWx0aCBka/i
            }
          )
        end
      end
    end

    context 'error handling' do
      it 'handles unknown errors' do
        uhd_service = double
        allow(UnifiedHealthData::Service).to receive(:new).with(user).and_return(uhd_service)
        allow(uhd_service).to receive(:get_single_summary_or_note).and_raise(StandardError.new('Unknown fetch error'))

        expect do
          uhd_service.get_single_summary_or_note('banana')
        end.to raise_error(StandardError, 'Unknown fetch error')
      end
    end
  end

  # Conditions
  describe '#get_conditions' do
    let(:conditions_sample_response) do
      JSON.parse(Rails.root.join('spec', 'fixtures', 'unified_health_data', 'conditions_sample_response.json').read)
    end
    let(:conditions_empty_vista_response) do
      JSON.parse(Rails.root.join(
        'spec', 'fixtures', 'unified_health_data', 'conditions_empty_vista_response.json'
      ).read)
    end
    let(:conditions_empty_oh_response) do
      JSON.parse(Rails.root.join('spec', 'fixtures', 'unified_health_data', 'conditions_empty_oh_response.json').read)
    end
    let(:conditions_empty_response) do
      JSON.parse(Rails.root.join('spec', 'fixtures', 'unified_health_data', 'conditions_empty_response.json').read)
    end

    let(:condition_attributes) do
      {
        'id' => be_a(String),
        'name' => be_a(String),
        'date' => be_a(String).or(be_nil),
        'provider' => be_a(String).or(be_nil),
        'facility' => be_a(String).or(be_nil),
        'comments' => be_an(Array).or(be_nil)
      }
    end

    before do
      allow(service).to receive(:fetch_access_token).and_return('token')
    end

    it 'returns conditions from both VistA and Oracle Health' do
      allow(service).to receive_messages(
        perform: double(body: conditions_sample_response),
        parse_response_body: conditions_sample_response
      )

      conditions = service.get_conditions
      expect(conditions.size).to eq(18)
      expect(conditions).to all(be_a(UnifiedHealthData::Condition))
      expect(conditions).to all(have_attributes(condition_attributes))
    end

    it 'returns conditions from both VistA and Oracle Health with real sample data' do
      allow(service).to receive_messages(
        perform: double(body: conditions_sample_response),
        parse_response_body: conditions_sample_response
      )

      conditions = service.get_conditions
      expect(conditions.size).to eq(18)
      expect(conditions).to all(be_a(UnifiedHealthData::Condition))
      expect(conditions).to all(have_attributes(condition_attributes))

      vista_conditions = conditions.select { |c| c.id.include?('-') }
      oh_conditions = conditions.reject { |c| c.id.include?('-') }
      expect(vista_conditions).not_to be_empty
      expect(oh_conditions).not_to be_empty

      depression_condition = conditions.find { |c| c.id == '2b4de3e7-0ced-43c6-9a8a-336b9171f4df' }
      covid_condition = conditions.find { |c| c.id == 'p1533314061' }

      expect(depression_condition).to have_attributes(
        name: 'Major depressive disorder, recurrent, moderate',
        provider: 'BORLAND,VICTORIA A',
        facility: 'CHYSHR TEST LAB'
      )

      expect(covid_condition).to have_attributes(
        name: 'Disease caused by 2019-nCoV',
        provider: 'SYSTEM, SYSTEM Cerner, Cerner Managed Acct',
        facility: 'WAMC Bariatric Surgery'
      )
    end

    it 'returns empty array when no data exists' do
      allow(service).to receive_messages(
        perform: double(body: conditions_empty_response),
        parse_response_body: conditions_empty_response
      )

      conditions = service.get_conditions
      expect(conditions).to eq([])
    end

    it 'returns conditions from Oracle Health only when VistA is empty' do
      allow(service).to receive_messages(
        perform: double(body: conditions_empty_vista_response),
        parse_response_body: conditions_empty_vista_response
      )

      conditions = service.get_conditions
      expect(conditions.size).to eq(2)
      expect(conditions).to all(be_a(UnifiedHealthData::Condition))
      covid_condition = conditions.find { |c| c.id == 'p1533314061' }
      expect(covid_condition.name).to eq('Disease caused by 2019-nCoV')
    end

    it 'returns conditions from VistA only when Oracle Health is empty' do
      allow(service).to receive_messages(
        perform: double(body: conditions_empty_oh_response),
        parse_response_body: conditions_empty_oh_response
      )

      conditions = service.get_conditions
      expect(conditions.size).to eq(16)
      expect(conditions).to all(be_a(UnifiedHealthData::Condition))
      first_condition = conditions.find { |c| c.id == '2b4de3e7-0ced-43c6-9a8a-336b9171f4df' }
      expect(first_condition.name).to eq('Major depressive disorder, recurrent, moderate')
    end

    it 'handles malformed responses gracefully' do
      allow(service).to receive_messages(
        perform: double(body: 'invalid'),
        parse_response_body: nil
      )

      expect { service.get_conditions }.not_to raise_error
      expect(service.get_conditions).to eq([])
    end

    it 'handles missing data sections without errors' do
      modified_response = JSON.parse(conditions_sample_response.to_json)
      modified_response['vista'] = nil
      modified_response['oracle-health'] = nil
      allow(service).to receive_messages(
        perform: double(body: conditions_sample_response),
        parse_response_body: modified_response
      )

      expect { service.get_conditions }.not_to raise_error
      expect(service.get_conditions).to be_an(Array)
    end
  end
end
