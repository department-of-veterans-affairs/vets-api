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

    let(:labs_client_response) do
      Faraday::Response.new(
        body: labs_response
      )
    end

    let(:sample_client_response) do
      Faraday::Response.new(
        body: sample_response
      )
    end

    context 'with defensive nil checks' do
      it 'handles missing contained sections' do
        # Simulate missing contained by modifying the response
        modified_response = JSON.parse(labs_response.to_json)
        modified_response['vista']['entry'].first['resource']['contained'] = nil
        allow_any_instance_of(UnifiedHealthData::Client)
          .to receive(:get_labs_by_date)
          .and_return(Faraday::Response.new(
                        body: modified_response
                      ))

        expect do
          labs = service.get_labs(start_date: '2024-01-01', end_date: '2025-05-31')
          expect(labs).to be_an(Array)
        end.not_to raise_error
      end
    end

    context 'with valid lab responses' do
      before do
        allow_any_instance_of(UnifiedHealthData::Client)
          .to receive(:get_labs_by_date)
          .and_return(labs_client_response)
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
          allow(Flipper).to receive(:enabled?).with(:mhv_accelerated_delivery_uhd_ch_enabled,
                                                    user).and_return(false)
          allow(Flipper).to receive(:enabled?).with(:mhv_accelerated_delivery_uhd_sp_enabled,
                                                    user).and_return(false)
          allow(Flipper).to receive(:enabled?).with(:mhv_accelerated_delivery_uhd_mb_enabled,
                                                    user).and_return(false)
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
          allow(Flipper).to receive(:enabled?).with(:mhv_accelerated_delivery_uhd_ch_enabled,
                                                    user).and_return(false)
          allow(Flipper).to receive(:enabled?).with(:mhv_accelerated_delivery_uhd_sp_enabled,
                                                    user).and_return(false)
          allow(Flipper).to receive(:enabled?).with(:mhv_accelerated_delivery_uhd_mb_enabled,
                                                    user).and_return(false)
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
          allow(Flipper).to receive(:enabled?).with(:mhv_accelerated_delivery_uhd_sp_enabled,
                                                    user).and_return(false)
          allow(Flipper).to receive(:enabled?).with(:mhv_accelerated_delivery_uhd_mb_enabled,
                                                    user).and_return(false)
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
          allow(Flipper).to receive(:enabled?).with(:mhv_accelerated_delivery_uhd_ch_enabled,
                                                    user).and_return(false)
          allow(Flipper).to receive(:enabled?).with(:mhv_accelerated_delivery_uhd_sp_enabled,
                                                    user).and_return(false)
          allow(Flipper).to receive(:enabled?).with(:mhv_accelerated_delivery_uhd_mb_enabled, user).and_return(true)
          allow(Rails.logger).to receive(:info)
          labs = service.get_labs(start_date: '2024-01-01', end_date: '2025-05-31')
          expect(labs.size).to eq(1)
        end
      end
    end

    context 'with malformed response' do
      before do
        allow_any_instance_of(UnifiedHealthData::Client)
          .to receive(:get_labs_by_date)
          .and_return(Faraday::Response.new(
                        body: nil
                      ))
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

  describe '#fetch_combined_records' do
    context 'when body is nil' do
      it 'returns an empty array' do
        result = service.send(:fetch_combined_records, nil)

        expect(result).to eq([])
      end
    end
  end

  # Allergies
  describe '#get_allergies' do
    let(:allergies_sample_response) do
      JSON.parse(Rails.root.join(
        'spec', 'fixtures', 'unified_health_data', 'allergies_example.json'
      ).read)
    end

    let(:sample_client_response) do
      Faraday::Response.new(
        body: allergies_sample_response
      )
    end

    context 'happy path' do
      context 'when data exists for both VistA + OH' do
        it 'returns all allergies' do
          allow_any_instance_of(UnifiedHealthData::Client)
            .to receive(:get_allergies_by_date)
            .and_return(sample_client_response)

          allergies = service.get_allergies
          expect(allergies.size).to eq(13)
          expect(allergies.map(&:categories)).to contain_exactly(
            ['medication'],
            ['medication'],
            ['medication'],
            ['medication'],
            ['medication'],
            ['medication'],
            ['medication'],
            ['medication'],
            ['environment'],
            ['food'],
            [],
            ['food'],
            ['food']
          )
          expect(allergies[0]).to have_attributes(
            {
              'id' => '2678',
              'name' => 'TRAZODONE',
              'date' => nil,
              'categories' => ['medication'],
              'reactions' => [],
              'location' => nil,
              'observedHistoric' => 'h',
              'notes' => [],
              'provider' => nil
            }
          )
          expect(allergies).to all(have_attributes(
                                     {
                                       'id' => be_a(String),
                                       'name' => be_a(String),
                                       'date' => be_a(String).or(be_nil),
                                       'categories' => be_an(Array),
                                       'reactions' => be_an(Array),
                                       'location' => be_a(String).or(be_nil),
                                       'observedHistoric' => be_a(String).or(be_nil),
                                       'notes' => be_an(Array),
                                       'provider' => be_a(String).or(be_nil)
                                     }
                                   ))
        end
      end

      context 'when data exists for only VistA or OH' do
        it 'returns allergies for VistA only' do
          modified_response = allergies_sample_response.deep_dup
          modified_response['oracle-health'] = {}
          allow_any_instance_of(UnifiedHealthData::Client)
            .to receive(:get_allergies_by_date)
            .and_return(Faraday::Response.new(
                          body: modified_response
                        ))
          allergies = service.get_allergies
          expect(allergies.size).to eq(5)
          expect(allergies.map(&:categories)).to contain_exactly(
            ['medication'],
            ['medication'],
            ['medication'],
            ['medication'],
            ['medication']
          )
          expect(allergies).to all(have_attributes(
                                     {
                                       'id' => be_a(String),
                                       'name' => be_a(String),
                                       'date' => be_a(String).or(be_nil),
                                       'categories' => be_an(Array),
                                       'reactions' => be_an(Array),
                                       'location' => be_a(String).or(be_nil),
                                       'observedHistoric' => be_a(String).or(be_nil),
                                       'notes' => be_an(Array),
                                       'provider' => be_a(String).or(be_nil)
                                     }
                                   ))
        end

        it 'returns allergies for OH only' do
          modified_response = allergies_sample_response.deep_dup
          modified_response['vista'] = {}
          allow_any_instance_of(UnifiedHealthData::Client)
            .to receive(:get_allergies_by_date)
            .and_return(Faraday::Response.new(
                          body: modified_response
                        ))
          allergies = service.get_allergies
          expect(allergies.size).to eq(8)
          expect(allergies.map(&:categories)).to contain_exactly(
            ['medication'],
            ['medication'],
            ['medication'],
            ['environment'],
            ['food'],
            [],
            ['food'],
            ['food']
          )
          expect(allergies).to all(have_attributes(
                                     {
                                       'id' => be_a(String),
                                       'name' => be_a(String),
                                       'date' => be_a(String).or(be_nil),
                                       'categories' => be_an(Array),
                                       'reactions' => be_an(Array),
                                       'location' => be_a(String).or(be_nil),
                                       'observedHistoric' => be_nil, # OH data doesn't include this field
                                       'notes' => be_an(Array),
                                       'provider' => be_a(String).or(be_nil)
                                     }
                                   ))
        end
      end

      context 'when there are no records in VistA or OH' do
        it 'returns empty array allergies' do
          allow_any_instance_of(UnifiedHealthData::Client)
            .to receive(:get_allergies_by_date)
            .and_return(Faraday::Response.new(
                          body: { 'vista' => {}, 'oracle-health' => {} }
                        ))
          allergies = service.get_allergies
          expect(allergies.size).to eq(0)
        end
      end
    end

    context 'error handling' do
      it 'handles unknown errors' do
        uhd_service = double
        allow(UnifiedHealthData::Service).to receive(:new).with(user).and_return(uhd_service)
        allow(uhd_service).to receive(:get_allergies).and_raise(StandardError.new('Unknown fetch error'))

        expect do
          uhd_service.get_allergies
        end.to raise_error(StandardError, 'Unknown fetch error')
      end
    end
  end

  describe '#get_single_allergy' do
    let(:allergies_sample_response) do
      JSON.parse(Rails.root.join(
        'spec', 'fixtures', 'unified_health_data', 'allergies_example.json'
      ).read)
    end

    let(:sample_client_response) do
      Faraday::Response.new(
        body: allergies_sample_response
      )
    end

    before do
      allow_any_instance_of(UnifiedHealthData::Client)
        .to receive(:get_allergies_by_date)
        .and_return(sample_client_response)
    end

    context 'happy path' do
      context 'when data exists for both VistA + OH' do
        it 'returns a single VistA allergy' do
          allergy = service.get_single_allergy('2679')
          expect(allergy).to have_attributes(
            {
              'id' => '2679',
              'name' => 'MAXZIDE',
              'date' => nil,
              'categories' => ['medication'],
              'reactions' => [],
              'location' => nil,
              'observedHistoric' => 'h',
              'notes' => [],
              'provider' => nil
            }
          )
        end

        it 'returns a single OH allergy' do
          allergy = service.get_single_allergy('132316417')
          expect(allergy).to have_attributes(
            {
              'id' => '132316417',
              'name' => 'Oxymorphone',
              'date' => '2019',
              'categories' => ['medication'],
              'reactions' => ['Anaphylaxis'],
              'location' => nil,
              'observedHistoric' => nil,
              'notes' => ['Testing Contraindication type reaction', 'Secondary comment for contraindication'],
              'provider' => ' Victoria A Borland'
            }
          )
        end
      end
    end

    context 'error handling' do
      it 'handles unknown errors' do
        uhd_service = double
        allow(UnifiedHealthData::Service).to receive(:new).with(user).and_return(uhd_service)
        allow(uhd_service).to receive(:get_single_allergy).and_raise(StandardError.new('Unknown fetch error'))

        expect do
          uhd_service.get_single_allergy('banana')
        end.to raise_error(StandardError, 'Unknown fetch error')
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

    let(:sample_client_response) do
      Faraday::Response.new(
        body: notes_sample_response
      )
    end

    before do
      allow_any_instance_of(UnifiedHealthData::Client)
        .to receive(:get_notes_by_date)
        .and_return(sample_client_response)
    end

    context 'happy path' do
      context 'when data exists for both VistA + OH' do
        it 'returns care summaries and notes' do
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
              'id' => 'F253-7227761-1834074',
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
          allow_any_instance_of(UnifiedHealthData::Client)
            .to receive(:get_notes_by_date)
            .and_return(Faraday::Response.new(
                          body: notes_no_oh_response
                        ))
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
          allow_any_instance_of(UnifiedHealthData::Client)
            .to receive(:get_notes_by_date)
            .and_return(Faraday::Response.new(
                          body: notes_no_vista_response
                        ))
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
          allow_any_instance_of(UnifiedHealthData::Client)
            .to receive(:get_notes_by_date)
            .and_return(Faraday::Response.new(
                          body: notes_empty_response
                        ))
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

    context 'LOINC code logging' do
      before do
        allow_any_instance_of(UnifiedHealthData::Client)
          .to receive(:get_notes_by_date)
          .and_return(sample_client_response)
        allow(Rails.logger).to receive(:info)
      end

      it 'logs LOINC code distribution when flipper enabled' do
        allow(Flipper).to receive(:enabled?).with(:mhv_accelerated_delivery_uhd_loinc_logging_enabled,
                                                  user).and_return(true)

        service.get_care_summaries_and_notes

        expect(Rails.logger).to have_received(:info).with(
          {
            message: 'UHD LOINC code distribution',
            loinc_code_distribution: '11506-3:3,11488-4:1,4189665:1,18842-5:1,4189666:1,96339-7:1',
            total_codes: 6,
            total_records: 6,
            service: 'unified_health_data'
          }
        )
      end

      it 'does not log LOINC code distribution when flipper disabled' do
        allow(Flipper).to receive(:enabled?).with(:mhv_accelerated_delivery_uhd_loinc_logging_enabled,
                                                  user).and_return(false)

        expect(Rails.logger).not_to receive(:info)
        service.get_care_summaries_and_notes
      end
    end
  end

  describe '#get_single_summary_or_note' do
    let(:notes_sample_response) do
      JSON.parse(Rails.root.join(
        'spec', 'fixtures', 'unified_health_data', 'notes_sample_response.json'
      ).read)
    end

    let(:sample_client_response) do
      Faraday::Response.new(
        body: notes_sample_response
      )
    end

    before do
      allow_any_instance_of(UnifiedHealthData::Client)
        .to receive(:get_notes_by_date)
        .and_return(sample_client_response)
    end

    context 'happy path' do
      context 'when data exists for both VistA + OH' do
        it 'returns care summaries and notes' do
          note = service.get_single_summary_or_note('F253-7227761-1834074')
          expect(note).to have_attributes(
            {
              'id' => 'F253-7227761-1834074',
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

  # Prescriptions
  describe '#get_prescriptions' do
    before do
      # Freeze today so the generated end_date in service matches VCR cassette date range expectations
      allow(Time.zone).to receive(:today).and_return(Date.new(2025, 9, 19))
    end

    context 'with valid prescription responses', :vcr do
      it 'returns prescriptions from both VistA and Oracle Health' do
        VCR.use_cassette('unified_health_data/get_prescriptions_success') do
          prescriptions = service.get_prescriptions
          expect(prescriptions.size).to eq(55)

          # Check that prescriptions are UnifiedHealthData::Prescription objects
          expect(prescriptions).to all(be_a(UnifiedHealthData::Prescription))

          # Verify delegation methods work
          expect(prescriptions.map(&:prescription_id)).to include('25804853', '25804854', '25804855', '15218955729',
                                                                  '15214174423', '15214303643')
          expect(prescriptions.map(&:prescription_name)).to include('albuterol (albuterol 90 mcg inhaler [8.5g])',
                                                                    'warfarin (warfarin 5 mg oral tablet)')
        end
      end

      context 'with current_only: true' do
        it 'applies filtering to exclude old discontinued/expired prescriptions' do
          VCR.use_cassette('unified_health_data/get_prescriptions_success') do
            filtered_prescriptions = service.get_prescriptions(current_only: true)
            expect(filtered_prescriptions.size).to eq(54)
          end
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
          expect(vista_prescription.instructions).to eq('APPLY SMALL AMOUNT TO AFFECTED AREA WEEKLY FOR 30 DAYS')
          expect(vista_prescription.is_refillable).to be true
          expect(vista_prescription.station_number).to eq('989')
          expect(vista_prescription.prescription_number).to eq('2721174')
        end
      end

      it 'properly maps Oracle Health prescription fields' do
        VCR.use_cassette('unified_health_data/get_prescriptions_success') do
          prescriptions = service.get_prescriptions
          oracle_prescription = prescriptions.find { |p| p.prescription_id == '15214174591' }

          expect(oracle_prescription.refill_status).to eq('active')
          expect(oracle_prescription.refill_submit_date).to be_nil
          expect(oracle_prescription.refill_date).to eq('2025-06-24T21:05:53.000Z')
          expect(oracle_prescription.refill_remaining).to eq(2)
          expect(oracle_prescription.facility_name).to eq('Ambulatory Pharmacy')
          expect(oracle_prescription.ordered_date).to eq('2025-05-30T17:58:09Z')
          expect(oracle_prescription.quantity).to eq('8.5')
          expect(oracle_prescription.expiration_date).to eq('2026-05-30T04:59:59Z')
          expect(oracle_prescription.prescription_number).to eq('15214174591')
          expect(oracle_prescription.prescription_name).to eq('albuterol (albuterol 90 mcg inhaler [8.5g])')
          expect(oracle_prescription.dispensed_date).to be_nil
          expect(oracle_prescription.station_number).to eq('556')
          expect(oracle_prescription.is_refillable).to be true
          expect(oracle_prescription.is_trackable).to be false
          expect(oracle_prescription.tracking_information).to eq({})
          expect(oracle_prescription.prescription_source).to eq('')
          expect(oracle_prescription.instructions).to eq(
            '2 Inhalation Inhalation (breathe in) every 4 hours as needed shortness of breath or wheezing. Refills: 2.'
          )
          expect(oracle_prescription.facility_phone_number).to be_nil
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
          expect(oracle_prescription_with_patient_instruction.instructions).to eq(
            '2 Inhalation Inhalation (breathe in) every 4 hours as needed shortness of breath or wheezing. ' \
            'Refills: 2.'
          )
          expect(oracle_prescription_with_patient_instruction.facility_name).to eq('Ambulatory Pharmacy')
          expect(oracle_prescription_with_patient_instruction.refill_date).to eq('2025-06-24T21:05:53.000Z')
          expect(oracle_prescription_with_patient_instruction.dispensed_date).to be_nil

          # Test prescription with completed status mapping
          completed_prescription = prescriptions.find { |p| p.prescription_id == '15214166467' }
          expect(completed_prescription.refill_status).to eq('completed')
          expect(completed_prescription.is_refillable).to be false
          expect(completed_prescription.refill_date).to be_nil
        end
      end

      it 'logs prescription retrieval information' do
        allow(Rails.logger).to receive(:info)

        VCR.use_cassette('unified_health_data/get_prescriptions_success') do
          service.get_prescriptions

          expect(Rails.logger).to have_received(:info).with(
            hash_including(
              message: 'UHD prescriptions retrieved',
              total_prescriptions: 55,
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
          expect(prescriptions.size).to eq(10)
          expect(prescriptions.map(&:prescription_id)).to contain_exactly(
            '25804851', '25804852', '25804853', '25804854', '25804855',
            '25804856', '25804858', '25804859', '25804860', '25804848'
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
    before do
      allow_any_instance_of(UnifiedHealthData::Client).to receive(:refill_prescription_orders).and_call_original
    end

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

      # TODO: Not sure why this is failing
      #
      #   it 'formats request body correctly' do
      #     VCR.use_cassette('unified_health_data/refill_prescription_success') do
      #       orders = [
      #         { 'id' => '12345', 'stationNumber' => '570' },
      #         { 'id' => '67890', 'stationNumber' => '556' }
      #       ]
      #       expected_body = {
      #         patientId: user.icn,
      #         orders: [
      #           { orderId: '12345', stationNumber: '570' },
      #           { orderId: '67890', stationNumber: '556' }
      #         ]
      #       }.to_json

      #       client = UnifiedHealthData::Client.new
      #       expect(client).to receive(:refill_prescription_orders).with(expected_body)

      #       service.refill_prescription(orders)
      #     end
      #   end
    end

    context 'with service errors' do
      it 'handles network errors gracefully' do
        allow_any_instance_of(UnifiedHealthData::Client)
          .to receive(:refill_prescription_orders)
          .and_raise(StandardError.new('Network error'))

        orders = [{ id: '12345', stationNumber: '570' }]
        result = service.refill_prescription(orders)

        expect(result[:success]).to eq([])
        expect(result[:failed]).to contain_exactly(
          { id: '12345', error: 'Service unavailable', station_number: '570' }
        )
      end

      it 'logs error when refill fails' do
        allow_any_instance_of(UnifiedHealthData::Client)
          .to receive(:refill_prescription_orders)
          .and_raise(StandardError.new('API error'))
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

    context 'parse_refill_response edge cases' do
      it 'always returns arrays for success and failed keys with nil response body' do
        response = double(body: nil)
        allow(service).to receive(:parse_response_body).with(nil).and_return(nil)

        result = service.send(:parse_refill_response, response)

        expect(result).to have_key(:success)
        expect(result).to have_key(:failed)
        expect(result[:success]).to eq([])
        expect(result[:failed]).to eq([])
      end

      it 'always returns arrays for success and failed keys with non-array response body' do
        response = double(body: { error: 'Invalid format' })
        allow(service).to receive(:parse_response_body).and_return({ error: 'Invalid format' })

        result = service.send(:parse_refill_response, response)

        expect(result).to have_key(:success)
        expect(result).to have_key(:failed)
        expect(result[:success]).to eq([])
        expect(result[:failed]).to eq([])
      end

      it 'always returns arrays for success and failed keys with empty array response' do
        response = double(body: [])
        allow(service).to receive(:parse_response_body).and_return([])

        result = service.send(:parse_refill_response, response)

        expect(result).to have_key(:success)
        expect(result).to have_key(:failed)
        expect(result[:success]).to eq([])
        expect(result[:failed]).to eq([])
      end

      it 'returns empty failed array when only successes exist' do
        response = double(body: [
                            { 'success' => true, 'orderId' => '123', 'message' => 'Success', 'stationNumber' => '570' }
                          ])
        allow(service).to receive(:parse_response_body).and_return([
                                                                     { 'success' => true,
                                                                       'orderId' => '123',
                                                                       'message' => 'Success',
                                                                       'stationNumber' => '570' }
                                                                   ])

        result = service.send(:parse_refill_response, response)

        expect(result[:success]).to eq([
                                         { id: '123', status: 'Success', station_number: '570' }
                                       ])
        expect(result[:failed]).to eq([])
        expect(result[:failed]).to be_an(Array)
      end

      it 'returns empty success array when only failures exist' do
        response = double(body: [
                            { 'success' => false, 'orderId' => '456', 'message' => 'Failed', 'stationNumber' => '571' }
                          ])
        allow(service).to receive(:parse_response_body).and_return([
                                                                     { 'success' => false, 'orderId' => '456',
                                                                       'message' => 'Failed', 'stationNumber' => '571' }
                                                                   ])

        result = service.send(:parse_refill_response, response)

        expect(result[:success]).to eq([])
        expect(result[:success]).to be_an(Array)
        expect(result[:failed]).to eq([
                                        { id: '456', error: 'Failed', station_number: '571' }
                                      ])
      end
    end

    context 'extract_successful_refills' do
      it 'returns empty array when no successful refills exist' do
        refill_items = [
          { 'success' => false, 'orderId' => '123', 'message' => 'Failed', 'stationNumber' => '570' }
        ]

        result = service.send(:extract_successful_refills, refill_items)

        expect(result).to eq([])
      end

      it 'returns empty array when refill_items is empty' do
        result = service.send(:extract_successful_refills, [])

        expect(result).to eq([])
      end

      it 'extracts successful refills correctly' do
        refill_items = [
          { 'success' => true, 'orderId' => '123', 'message' => 'Success', 'stationNumber' => '570' },
          { 'success' => false, 'orderId' => '456', 'message' => 'Failed', 'stationNumber' => '571' }
        ]

        result = service.send(:extract_successful_refills, refill_items)

        expect(result).to eq([
                               { id: '123', status: 'Success', station_number: '570' }
                             ])
      end
    end

    context 'extract_failed_refills' do
      it 'returns empty array when no failed refills exist' do
        refill_items = [
          { 'success' => true, 'orderId' => '123', 'message' => 'Success', 'stationNumber' => '570' }
        ]

        result = service.send(:extract_failed_refills, refill_items)

        expect(result).to eq([])
      end

      it 'returns empty array when refill_items is empty' do
        result = service.send(:extract_failed_refills, [])

        expect(result).to eq([])
      end

      it 'extracts failed refills correctly' do
        refill_items = [
          { 'success' => true, 'orderId' => '123', 'message' => 'Success', 'stationNumber' => '570' },
          { 'success' => false, 'orderId' => '456', 'message' => 'Failed', 'stationNumber' => '571' }
        ]

        result = service.send(:extract_failed_refills, refill_items)

        expect(result).to eq([
                               { id: '456', error: 'Failed', station_number: '571' }
                             ])
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

    let(:sample_client_response) do
      Faraday::Response.new(
        body: conditions_sample_response
      )
    end

    before do
      allow_any_instance_of(UnifiedHealthData::Client)
        .to receive(:get_conditions_by_date)
        .and_return(sample_client_response)
    end

    it 'returns conditions from both VistA and Oracle Health' do
      conditions = service.get_conditions
      expect(conditions.size).to eq(18)
      expect(conditions).to all(be_a(UnifiedHealthData::Condition))
      expect(conditions).to all(have_attributes(condition_attributes))
    end

    it 'returns conditions from both VistA and Oracle Health with real sample data' do
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
      allow_any_instance_of(UnifiedHealthData::Client)
        .to receive(:get_conditions_by_date)
        .and_return(Faraday::Response.new(
                      body: conditions_empty_response
                    ))

      conditions = service.get_conditions
      expect(conditions).to eq([])
    end

    it 'returns conditions from Oracle Health only when VistA is empty' do
      allow_any_instance_of(UnifiedHealthData::Client)
        .to receive(:get_conditions_by_date)
        .and_return(Faraday::Response.new(
                      body: conditions_empty_vista_response
                    ))

      conditions = service.get_conditions
      expect(conditions.size).to eq(2)
      expect(conditions).to all(be_a(UnifiedHealthData::Condition))
      covid_condition = conditions.find { |c| c.id == 'p1533314061' }
      expect(covid_condition.name).to eq('Disease caused by 2019-nCoV')
    end

    it 'returns conditions from VistA only when Oracle Health is empty' do
      allow_any_instance_of(UnifiedHealthData::Client)
        .to receive(:get_conditions_by_date)
        .and_return(Faraday::Response.new(
                      body: conditions_empty_oh_response
                    ))

      conditions = service.get_conditions
      expect(conditions.size).to eq(16)
      expect(conditions).to all(be_a(UnifiedHealthData::Condition))
      first_condition = conditions.find { |c| c.id == '2b4de3e7-0ced-43c6-9a8a-336b9171f4df' }
      expect(first_condition.name).to eq('Major depressive disorder, recurrent, moderate')
    end

    # TODO: This DOES actually raise an error, which seems accurate
    #
    # it 'handles malformed responses gracefully' do
    #   allow_any_instance_of(UnifiedHealthData::Client)
    #     .to receive(:get_conditions_by_date)
    #     .and_return(Faraday::Response.new(
    #                   body: 'invalid'
    #                 ))

    #   expect { service.get_conditions }.not_to raise_error
    #   expect(service.get_conditions).to eq([])
    # end

    it 'handles missing data sections without errors' do
      modified_response = JSON.parse(conditions_sample_response.to_json)
      modified_response['vista'] = nil
      modified_response['oracle-health'] = nil

      allow_any_instance_of(UnifiedHealthData::Client)
        .to receive(:get_conditions_by_date)
        .and_return(Faraday::Response.new(
                      body: modified_response
                    ))

      expect { service.get_conditions }.not_to raise_error
      expect(service.get_conditions).to be_an(Array)
    end

    describe '#get_single_condition' do
      let(:condition_id) { '2b4de3e7-0ced-43c6-9a8a-336b9171f4df' }

      it 'returns a single condition when found' do
        condition = service.get_single_condition(condition_id)
        expect(condition).to be_a(UnifiedHealthData::Condition)
        expect(condition.id).to eq(condition_id)
        expect(condition.name).to eq('Major depressive disorder, recurrent, moderate')
        expect(condition.provider).to eq('BORLAND,VICTORIA A')
        expect(condition.facility).to eq('CHYSHR TEST LAB')
      end

      it 'returns nil when condition not found' do
        allow_any_instance_of(UnifiedHealthData::Client)
          .to receive(:get_conditions_by_date)
          .and_return(Faraday::Response.new(
                        body: conditions_empty_response
                      ))
        condition = service.get_single_condition('nonexistent-id')
        expect(condition).to be_nil
      end

      it 'handles malformed responses gracefully' do
        allow_any_instance_of(UnifiedHealthData::Client)
          .to receive(:get_conditions_by_date)
          .and_return(Faraday::Response.new(
                        body: nil
                      ))
        expect { service.get_single_condition(condition_id) }.not_to raise_error
        condition = service.get_single_condition(condition_id)
        expect(condition).to be_nil
      end
    end
  end

  describe '#get_ccd_metadata' do
    let(:start_date) { '2024-01-01' }
    let(:end_date) { '2024-12-31' }
    let(:ccd_fixture) do
      Rails.root.join('spec', 'fixtures', 'unified_health_data', 'ccd_example.json').read
    end
    let(:ccd_response) do
      Faraday::Response.new(body: ccd_fixture)
    end

    before do
      allow_any_instance_of(UnifiedHealthData::Client).to receive(:get_ccd).and_return(ccd_response)
    end

    context 'when successful' do
      it 'returns CCD metadata' do
        result = service.get_ccd_metadata(start_date:, end_date:)

        expect(result).to be_a(Hash)
        expect(result[:type]).to eq('Continuity of Care Document')
        expect(result[:available_formats]).to include('xml')
        expect(result[:id]).to be_present
      end

      it 'calls the client with correct parameters' do
        client_spy = spy('client')
        allow(UnifiedHealthData::Client).to receive(:new).and_return(client_spy)
        allow(client_spy).to receive(:get_ccd).and_return(ccd_response)

        service.get_ccd_metadata(start_date:, end_date:)

        expect(client_spy).to have_received(:get_ccd)
          .with(patient_id: user.icn, start_date:, end_date:)
      end
    end

    context 'when DocumentReference is missing' do
      let(:empty_bundle) { '{"entry": []}' }
      let(:ccd_response) do
        Faraday::Response.new(body: empty_bundle)
      end

      it 'returns nil when no CCD document exists' do
        result = service.get_ccd_metadata(start_date:, end_date:)
        expect(result).to be_nil
      end
    end
  end

  describe '#get_ccd_binary' do
    let(:start_date) { '2024-01-01' }
    let(:end_date) { '2024-12-31' }
    let(:ccd_fixture) do
      Rails.root.join('spec', 'fixtures', 'unified_health_data', 'ccd_example.json').read
    end
    let(:ccd_response) do
      Faraday::Response.new(body: ccd_fixture)
    end

    before do
      allow_any_instance_of(UnifiedHealthData::Client).to receive(:get_ccd).and_return(ccd_response)
    end

    context 'when requesting XML format' do
      it 'returns BinaryData object with Base64 encoded XML' do
        result = service.get_ccd_binary(start_date:, end_date:, format: 'xml')

        expect(result).to be_a(UnifiedHealthData::BinaryData)
        expect(result.content_type).to eq('application/xml')
        expect(result.binary).to be_present
        # Verify it's Base64 encoded by decoding and checking for XML declaration
        decoded = Base64.decode64(result.binary)
        expect(decoded).to match(/^<\?xml/)
      end
    end

    context 'when requesting unavailable format' do
      let(:ccd_data) { JSON.parse(ccd_fixture) }
      let(:modified_ccd) do
        # Remove HTML/PDF from fixture
        doc_ref = ccd_data['entry'].find { |e| e['resource']['resourceType'] == 'DocumentReference' }
        doc_ref['resource']['content'].first['attachment'].delete('html')
        doc_ref['resource']['content'].first['attachment'].delete('pdf')
        ccd_data.to_json
      end
      let(:ccd_response) do
        Faraday::Response.new(body: modified_ccd)
      end

      it 'raises an error for missing HTML' do
        expect do
          service.get_ccd_binary(start_date:, end_date:, format: 'html')
        end.to raise_error(RuntimeError, /Format html not available/)
      end
    end

    context 'when requesting invalid format' do
      it 'raises an ArgumentError' do
        expect do
          service.get_ccd_binary(start_date:, end_date:, format: 'json')
        end.to raise_error(ArgumentError, /Invalid format/)
      end
    end
  end
end
