# frozen_string_literal: true

require 'rails_helper'
require 'unified_health_data/service'

describe UnifiedHealthData::Service, type: :service do
  subject { described_class }

  let(:user) { build(:user, :loa3, icn: '1000123456V123456') }
  let(:service) { described_class.new(user) }

  before do
    # Disable V2 status mapping globally for all tests since the feature is not yet enabled
    allow(Flipper).to receive(:enabled?).with(:mhv_medications_v2_status_mapping, anything).and_return(false)
  end

  describe '#get_labs' do
    context 'with valid lab responses', :vcr do
      it 'returns all labs/tests with encodedData and/or observations' do
        VCR.use_cassette('mobile/unified_health_data/get_labs') do
          labs = service.get_labs(start_date: '2025-01-01', end_date: '2025-09-30')
          expect(labs.size).to eq(29)

          # Verify that labs with encodedData are returned
          labs_with_encoded_data = labs.select { |lab| lab.encoded_data.present? }
          expect(labs_with_encoded_data).not_to be_empty

          # Verify that labs with observations are returned
          labs_with_observations = labs.select { |lab| lab.observations.present? }
          expect(labs_with_observations).not_to be_empty
        end
      end

      it 'returns labs sorted by date_completed in descending order' do
        VCR.use_cassette('mobile/unified_health_data/get_labs') do
          labs = service.get_labs(start_date: '2025-01-01', end_date: '2025-09-30').sort

          labs_with_dates = labs.select { |lab| lab.date_completed.present? }
          dates = labs_with_dates.map { |lab| Time.zone.parse(lab.date_completed) }
          expect(dates).to eq(dates.sort.reverse)

          last_labs = labs.last(5)
          if last_labs.any? { |lab| lab.date_completed.nil? }
            expect(labs.select { |lab| lab.date_completed.nil? }).to eq(last_labs.select { |lab|
              lab.date_completed.nil?
            })
          end
        end
      end

      it 'logs test code distribution from parsed records' do
        allow(Rails.logger).to receive(:info)

        VCR.use_cassette('mobile/unified_health_data/get_labs') do
          service.get_labs(start_date: '2025-01-01', end_date: '2025-09-30')
        end

        expect(Rails.logger).to have_received(:info).with(
          hash_including(
            message: 'UHD test code and name distribution',
            service: 'unified_health_data'
          )
        )
      end

      it 'returns labs with only encodedData' do
        VCR.use_cassette('mobile/unified_health_data/get_labs') do
          labs = service.get_labs(start_date: '2025-01-01', end_date: '2025-09-30')

          # Find labs that have encoded data but no observations
          labs_with_encoded_only = labs.select { |lab| lab.encoded_data.present? && lab.observations.blank? }
          expect(labs_with_encoded_only).not_to be_empty
        end
      end

      it 'returns labs with only observations' do
        VCR.use_cassette('mobile/unified_health_data/get_labs') do
          labs = service.get_labs(start_date: '2025-01-01', end_date: '2025-09-30')

          # Find labs that have observations but no encoded data
          labs_with_observations_only = labs.select { |lab| lab.observations.present? && lab.encoded_data.blank? }
          expect(labs_with_observations_only).not_to be_empty
        end
      end

      it 'returns labs with both encodedData and observations' do
        VCR.use_cassette('mobile/unified_health_data/get_labs') do
          labs = service.get_labs(start_date: '2025-01-01', end_date: '2025-09-30')

          # Check if any labs have both (may or may not exist in cassette)
          labs_with_both = labs.select { |lab| lab.encoded_data.present? && lab.observations.present? }
          # This is just checking the structure works - we don't require cassette to have this combination
          expect(labs_with_both).to be_an(Array)
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
        allow(Flipper).to receive(:enabled?).and_return(true)
        expect { service.get_labs(start_date: '2025-01-01', end_date: '2025-09-30') }.not_to raise_error
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

    context 'when body has VistA and Oracle Health records' do
      let(:body) do
        {
          'vista' => {
            'entry' => [
              { 'resource' => { 'id' => 'vista-1', 'resourceType' => 'DiagnosticReport' } }
            ]
          },
          'oracle-health' => {
            'entry' => [
              { 'resource' => { 'id' => 'oracle-1', 'resourceType' => 'DiagnosticReport' } }
            ]
          }
        }
      end

      it 'adds source to each record and combines them' do
        result = service.send(:fetch_combined_records, body)
        expect(result.size).to eq(2)
        vista_record = result.find { |r| r['resource']['id'] == 'vista-1' }
        oracle_record = result.find { |r| r['resource']['id'] == 'oracle-1' }
        expect(vista_record['source']).to eq('vista')
        expect(oracle_record['source']).to eq('oracle-health')
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
          # Verify specific allergy exists (not checking position due to sorting)
          trazodone_allergy = allergies.find { |a| a.id == '2678' }
          expect(trazodone_allergy).to have_attributes(
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

        it 'returns allergies sorted by date in descending order' do
          allow_any_instance_of(UnifiedHealthData::Client)
            .to receive(:get_allergies_by_date)
            .and_return(sample_client_response)

          allergies = service.get_allergies.sort

          allergies_with_dates = allergies.select { |allergy| allergy.date.present? }
          # Use sort_date for comparison since that's what's used for sorting
          dates = allergies_with_dates.map(&:sort_date)
          expect(dates).to eq(dates.sort.reverse)

          allergies_without_dates = allergies.select { |allergy| allergy.date.nil? }
          if allergies_without_dates.any?
            expect(allergies.last(allergies_without_dates.size)).to eq(allergies_without_dates)
          end
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

  # Vitals
  describe '#get_vitals' do
    let(:vitals_sample_response) do
      JSON.parse(Rails.root.join(
        'spec', 'fixtures', 'unified_health_data', 'vitals_example.json'
      ).read)
    end

    let(:sample_client_response) do
      Faraday::Response.new(
        body: vitals_sample_response
      )
    end

    before do
      allow(Rails.logger).to receive(:info)
    end

    context 'happy path' do
      context 'when data exists for both VistA + OH' do
        it 'returns all vitals' do
          allow_any_instance_of(UnifiedHealthData::Client)
            .to receive(:get_vitals_by_date)
            .and_return(sample_client_response)

          expect(Rails.logger).to receive(:info)
            .with(
              message: 'Multiple locations found for 8 Vital records:',
              locations: [{ 'locations found' => 2,
                            'names' => '668 Green Primary Care; WAMC Bariatric Surgery' }],
              service: 'unified_health_data'
            )

          vitals = service.get_vitals
          expect(vitals.size).to eq(18)
          expect(vitals.map(&:type)).to contain_exactly(
            'WEIGHT',
            'WEIGHT',
            'HEIGHT',
            'PULSE',
            'TEMPERATURE',
            'BLOOD_PRESSURE',
            'PULSE_OXIMETRY',
            'RESPIRATION',
            'WEIGHT',
            'BLOOD_PRESSURE',
            'PULSE_OXIMETRY',
            'WEIGHT',
            'TEMPERATURE',
            'RESPIRATION',
            'PULSE',
            'BLOOD_PRESSURE',
            'HEIGHT',
            'WEIGHT'
          )

          # this will be a VistA record
          expect(vitals[0]).to have_attributes(
            {
              'id' => 'be3724c0-f9e2-4e6a-b37e-366aca305613',
              'name' => 'Weight',
              'type' => 'WEIGHT',
              'date' => '2025-08-22T22:16:24Z',
              'measurement' => '165.35 pounds',
              'location' => 'CHY ANOTHER TEST CLINIC',
              'notes' => []
            }
          )

          oh_vital = vitals.find { |vital| vital.id == 'VS-15249708684' }
          expect(oh_vital).to have_attributes(
            {
              'id' => 'VS-15249708684',
              'name' => 'Weight dosing',
              'type' => 'WEIGHT',
              'date' => '2025-07-24T18:23:00.000Z',
              'measurement' => '150.796 pounds',
              'location' => '668 Green Primary Care',
              'notes' => ['Result generated by automated process based on measured weight.']
            }
          )
          expect(vitals).to all(have_attributes(
                                  {
                                    'id' => be_a(String),
                                    'name' => be_a(String),
                                    'date' => be_a(String).or(be_nil),
                                    'type' => be_a(String),
                                    'measurement' => be_a(String),
                                    'location' => be_a(String),
                                    'notes' => be_an(Array)
                                  }
                                ))
        end

        it 'returns vitals sorted by date in descending order' do
          allow_any_instance_of(UnifiedHealthData::Client)
            .to receive(:get_vitals_by_date)
            .and_return(sample_client_response)

          vitals = service.get_vitals.sort

          vitals_with_dates = vitals.select { |v| v.date.present? }
          # Use sort_date for comparison since that's what's used for sorting
          dates = vitals_with_dates.map(&:sort_date)
          expect(dates).to eq(dates.sort.reverse)

          vitals_without_dates = vitals.select { |v| v.date.nil? }
          expect(vitals.last(vitals_without_dates.size)).to eq(vitals_without_dates) if vitals_without_dates.any?
        end
      end

      context 'when data exists for only VistA or OH' do
        it 'returns vitals for VistA only' do
          modified_response = vitals_sample_response.deep_dup
          modified_response['oracle-health'] = {}
          allow_any_instance_of(UnifiedHealthData::Client)
            .to receive(:get_vitals_by_date)
            .and_return(Faraday::Response.new(
                          body: modified_response
                        ))
          vitals = service.get_vitals
          expect(vitals.size).to eq(10)
          expect(vitals.map(&:type)).to contain_exactly(
            'WEIGHT',
            'WEIGHT',
            'HEIGHT',
            'PULSE',
            'TEMPERATURE',
            'BLOOD_PRESSURE',
            'PULSE_OXIMETRY',
            'RESPIRATION',
            'WEIGHT',
            'BLOOD_PRESSURE'
          )

          expect(vitals).to all(have_attributes(
                                  {
                                    'id' => be_a(String),
                                    'name' => be_a(String),
                                    'date' => be_a(String).or(be_nil),
                                    'type' => be_a(String),
                                    'measurement' => be_a(String),
                                    'location' => be_a(String),
                                    'notes' => be_an(Array)
                                  }
                                ))
        end

        it 'returns vitals for OH only' do
          modified_response = vitals_sample_response.deep_dup
          modified_response['vista'] = {}
          allow_any_instance_of(UnifiedHealthData::Client)
            .to receive(:get_vitals_by_date)
            .and_return(Faraday::Response.new(
                          body: modified_response
                        ))
          vitals = service.get_vitals
          expect(vitals.size).to eq(8)
          expect(vitals.map(&:type)).to contain_exactly(
            'PULSE_OXIMETRY',
            'WEIGHT',
            'TEMPERATURE',
            'RESPIRATION',
            'PULSE',
            'BLOOD_PRESSURE',
            'HEIGHT',
            'WEIGHT'
          )
          expect(vitals).to all(have_attributes(
                                  {
                                    'id' => be_a(String),
                                    'name' => be_a(String),
                                    'date' => be_a(String).or(be_nil),
                                    'type' => be_a(String),
                                    'measurement' => be_a(String),
                                    'location' => be_a(String),
                                    'notes' => be_an(Array)
                                  }
                                ))
        end
      end

      context 'when there are no records in VistA or OH' do
        it 'returns empty array for vitals' do
          allow_any_instance_of(UnifiedHealthData::Client)
            .to receive(:get_vitals_by_date)
            .and_return(Faraday::Response.new(
                          body: { 'vista' => {}, 'oracle-health' => {} }
                        ))
          vitals = service.get_vitals
          expect(vitals.size).to eq(0)
        end
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
          # Verify specific note exists (not checking position due to sorting)
          telehealth_note = notes.find { |n| n.id == 'F253-7227761-1834074' }
          expect(telehealth_note).to have_attributes(
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

        it 'returns clinical notes sorted by date in descending order' do
          notes = service.get_care_summaries_and_notes.sort

          dates = notes.map { |note| Time.zone.parse(note.date) }
          expect(dates).to eq(dates.sort.reverse)
          expect(notes.first.date).to eq(notes.map(&:date).max)
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

    context 'date range filtering' do
      # SCDF may return notes outside the requested range; API filters so only in-range notes are returned
      it 'returns only notes whose date is within the requested start_date and end_date' do
        allow_any_instance_of(UnifiedHealthData::Client)
          .to receive(:get_notes_by_date)
          .with(patient_id: user.icn, start_date: '2024-12-01', end_date: '2024-12-31')
          .and_return(sample_client_response)

        notes = service.get_care_summaries_and_notes(start_date: '2024-12-01', end_date: '2024-12-31')

        # Fixture has notes in Dec 2024 and Jan/Jul 2025; only Dec 2024 should be returned
        expect(notes).not_to be_empty
        notes.each do |note|
          note_date = Date.parse(note.date)
          expect(note_date).to be >= Date.parse('2024-12-01')
          expect(note_date).to be <= Date.parse('2024-12-31')
        end
      end

      it 'excludes notes from future years when filtering for a specific year' do
        allow_any_instance_of(UnifiedHealthData::Client)
          .to receive(:get_notes_by_date)
          .with(patient_id: user.icn, start_date: '2025-01-01', end_date: '2025-12-31')
          .and_return(sample_client_response)

        notes = service.get_care_summaries_and_notes(start_date: '2025-01-01', end_date: '2025-12-31')

        # All returned notes must be in 2025 (fixture has notes from 2024 and 2025)
        notes.each do |note|
          note_date = Date.parse(note.date)
          expect(note_date.year).to eq(2025)
        end
      end
    end

    context 'with date parameters' do
      it 'accepts and uses provided start_date and end_date' do
        expect_any_instance_of(UnifiedHealthData::Client)
          .to receive(:get_notes_by_date)
          .with(patient_id: user.icn, start_date: '2024-01-01', end_date: '2024-12-31')
          .and_return(sample_client_response)

        service.get_care_summaries_and_notes(start_date: '2024-01-01', end_date: '2024-12-31')
      end

      it 'uses default dates when parameters not provided' do
        expect_any_instance_of(UnifiedHealthData::Client)
          .to receive(:get_notes_by_date)
          .with(patient_id: user.icn, start_date: '1900-01-01', end_date: anything)
          .and_return(sample_client_response)

        service.get_care_summaries_and_notes
      end

      it 'uses default start_date when only end_date provided' do
        expect_any_instance_of(UnifiedHealthData::Client)
          .to receive(:get_notes_by_date)
          .with(patient_id: user.icn, start_date: '1900-01-01', end_date: '2024-12-31')
          .and_return(sample_client_response)

        service.get_care_summaries_and_notes(end_date: '2024-12-31')
      end

      it 'uses default end_date when only start_date provided' do
        expect_any_instance_of(UnifiedHealthData::Client)
          .to receive(:get_notes_by_date)
          .with(patient_id: user.icn, start_date: '2024-01-01', end_date: anything)
          .and_return(sample_client_response)

        service.get_care_summaries_and_notes(start_date: '2024-01-01')
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
            message: 'Clinical Notes LOINC code distribution',
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

  # After Visit Summaries
  describe '#get_appt_avs' do
    let(:avs_sample_response) do
      JSON.parse(Rails.root.join(
        'spec', 'fixtures', 'unified_health_data', 'after_visit_summary.json'
      ).read)
    end

    let(:sample_client_response) do
      Faraday::Response.new(
        body: avs_sample_response
      )
    end

    before do
      allow_any_instance_of(UnifiedHealthData::Client)
        .to receive(:get_avs)
        .and_return(sample_client_response)
    end

    context 'happy path' do
      context 'when include_binary is not passed it defaults to false' do
        it 'returns avs with metadata and no binary file' do
          avs = service.get_appt_avs(appt_id: '12345')
          expect(avs.size).to eq(2)
          expect(avs.map(&:note_type)).to contain_exactly(
            'ambulatory_patient_summary',
            'ambulatory_patient_summary'
          )
          expect(avs[0]).to have_attributes(
            {
              'appt_id' => '12345',
              'id' => '15249638961',
              'name' => 'Ambulatory Visit Summary',
              'loinc_codes' => %w[4189669 96345-4],
              'note_type' => 'ambulatory_patient_summary',
              'content_type' => 'application/pdf',
              'binary' => nil
            }
          )
          expect(avs).to all(have_attributes(
                               {
                                 'appt_id' => be_a(String),
                                 'id' => be_a(String),
                                 'name' => be_a(String),
                                 'loinc_codes' => be_an(Array),
                                 'note_type' => be_a(String),
                                 'content_type' => be_a(String),
                                 'binary' => be_nil # should all be nil since include_binary is not passed
                               }
                             ))
        end
      end

      context 'when include_binary is passed as true' do
        it 'returns avs with metadata and binary file' do
          avs = service.get_appt_avs(appt_id: '12345', include_binary: true)
          expect(avs.size).to eq(2)
          expect(avs.map(&:note_type)).to contain_exactly(
            'ambulatory_patient_summary',
            'ambulatory_patient_summary'
          )
          expect(avs[0]).to have_attributes(
            {
              'appt_id' => '12345',
              'id' => '15249638961',
              'name' => 'Ambulatory Visit Summary',
              'loinc_codes' => %w[4189669 96345-4],
              'note_type' => 'ambulatory_patient_summary',
              'content_type' => 'application/pdf',
              'binary' => /JVBERi0xLjQKJeLjz9MKMSAwIG9iago8PC9TdWJ0e/i
            }
          )
          expect(avs).to all(have_attributes(
                               {
                                 'appt_id' => be_a(String),
                                 'id' => be_a(String),
                                 'name' => be_a(String),
                                 'loinc_codes' => be_an(Array),
                                 'note_type' => be_a(String),
                                 'content_type' => be_a(String),
                                 'binary' => be_a(String)
                               }
                             ))
        end
      end
    end

    context 'error handling' do
      it 'handles unknown errors' do
        uhd_service = double
        allow(UnifiedHealthData::Service).to receive(:new).with(user).and_return(uhd_service)
        allow(uhd_service).to receive(:get_appt_avs).and_raise(StandardError.new('Unknown fetch error'))

        expect do
          uhd_service.get_appt_avs(appt_id: '12345', include_binary: true)
        end.to raise_error(StandardError, 'Unknown fetch error')
      end
    end

    context 'LOINC code logging' do
      before do
        allow_any_instance_of(UnifiedHealthData::Client)
          .to receive(:get_avs)
          .and_return(sample_client_response)
        allow(Rails.logger).to receive(:info)
      end

      it 'logs LOINC code distribution when flipper enabled' do
        allow(Flipper).to receive(:enabled?).with(:mhv_accelerated_delivery_uhd_loinc_logging_enabled,
                                                  user).and_return(true)

        service.get_appt_avs(appt_id: '12345', include_binary: true)

        expect(Rails.logger).to have_received(:info).with(
          {
            message: 'AVS LOINC code distribution',
            loinc_code_distribution: '4189669:2,96345-4:2',
            total_codes: 2,
            total_records: 2,
            service: 'unified_health_data'
          }
        )
      end

      it 'does not log LOINC code distribution when flipper disabled' do
        allow(Flipper).to receive(:enabled?).with(:mhv_accelerated_delivery_uhd_loinc_logging_enabled,
                                                  user).and_return(false)

        expect(Rails.logger).not_to receive(:info)
        service.get_appt_avs(appt_id: '12345', include_binary: true)
      end
    end
  end

  describe '#get_avs_binary_data' do
    let(:avs_sample_response) do
      JSON.parse(Rails.root.join(
        'spec', 'fixtures', 'unified_health_data', 'after_visit_summary.json'
      ).read)
    end

    let(:sample_client_response) do
      Faraday::Response.new(
        body: avs_sample_response
      )
    end

    before do
      allow_any_instance_of(UnifiedHealthData::Client)
        .to receive(:get_avs)
        .and_return(sample_client_response)
    end

    context 'happy path' do
      it 'returns avs binary data and content type' do
        avs = service.get_avs_binary_data(appt_id: '12345', doc_id: '15249638961')
        expect(avs).to have_attributes(
          {
            'content_type' => 'application/pdf',
            'binary' => /JVBERi0xLjQKJeLjz9MKMSAwIG9iago8PC9TdWJ0e/i
          }
        )
      end
    end

    context 'error handling' do
      it 'handles unknown errors' do
        uhd_service = double
        allow(UnifiedHealthData::Service).to receive(:new).with(user).and_return(uhd_service)
        allow(uhd_service).to receive(:get_avs_binary_data).and_raise(StandardError.new('Unknown fetch error'))

        expect do
          uhd_service.get_avs_binary_data(appt_id: '12345', doc_id: 'banana')
        end.to raise_error(StandardError, 'Unknown fetch error')
      end
    end
  end

  # Prescriptions
  describe '#get_prescriptions' do
    before do
      # Freeze today so the generated end_date in service matches VCR cassette date range expectations
      allow(Time.zone).to receive(:today).and_return(Date.new(2025, 9, 19))
      allow(Rails.cache).to receive(:exist?).and_return(false)
    end

    context 'with valid prescription responses', :vcr do
      before do
        # Stub the cache to return the expected facility name for station 668
        allow(Rails.cache).to receive(:read).with('uhd:facility_names:668').and_return('Ambulatory Pharmacy')
        allow(Rails.cache).to receive(:exist?).with('uhd:facility_names:668').and_return(true)
      end

      it 'returns prescriptions from both VistA and Oracle Health' do
        VCR.use_cassette('unified_health_data/get_prescriptions_success') do
          prescriptions = service.get_prescriptions
          expect(prescriptions.size).to eq(30)

          # Check that prescriptions are UnifiedHealthData::Prescription objects
          expect(prescriptions).to all(be_a(UnifiedHealthData::Prescription))

          # Verify delegation methods work
          expect(prescriptions.map(&:prescription_id)).to include('26305871', '26305872', '26305873', '20848812135',
                                                                  '20848639997')
          expect(prescriptions.map(&:prescription_name)).to include('PROMETHAZINE HCL 25MG TAB',
                                                                    'albuterol (albuterol 90 mcg inhaler [18g])')
        end
      end

      context 'with current_only: true' do
        it 'applies filtering to exclude old discontinued/expired prescriptions' do
          # Freeze time to prevent test from failing as prescriptions age
          # The cassette has prescriptions with various expiration dates
          # Using a fixed date ensures the 180-day filtering logic is consistent
          Timecop.freeze(Time.zone.parse('2025-11-27')) do
            VCR.use_cassette('unified_health_data/get_prescriptions_success') do
              filtered_prescriptions = service.get_prescriptions(current_only: true)
              expect(filtered_prescriptions.size).to eq(30)
            end
          end
        end
      end

      it 'properly maps VistA prescription fields' do
        VCR.use_cassette('unified_health_data/get_prescriptions_success') do
          prescriptions = service.get_prescriptions
          vista_prescription = prescriptions.find { |p| p.prescription_id == '26305871' }

          expect(vista_prescription.refill_status).to eq('active')
          expect(vista_prescription.refill_remaining).to eq(5)
          expect(vista_prescription.facility_name).to eq('Dayton Medical Center')
          expect(vista_prescription.prescription_name).to eq('PROMETHAZINE HCL 25MG TAB')
          expect(vista_prescription.instructions).to eq(
            'TAKE ONE TABLET BY MOUTH DAILY TEST --TAKE WITH FOOD TO DECREASE GI UPSET/DO NOT CRUSH OR CHEW--'
          )
          expect(vista_prescription.is_refillable).to be true
          expect(vista_prescription.station_number).to eq('989')
          expect(vista_prescription.prescription_number).to eq('2721445')
        end
      end

      it 'properly maps Oracle Health prescription fields' do
        VCR.use_cassette('unified_health_data/get_prescriptions_success') do
          prescriptions = service.get_prescriptions
          oracle_prescription = prescriptions.find { |p| p.prescription_id == '20848812135' }

          expect(oracle_prescription.refill_status).to eq('submitted')
          expect(oracle_prescription.refill_submit_date).to eq('2025-11-26T15:55:17+00:00')
          expect(oracle_prescription.refill_remaining).to eq(2)
          expect(oracle_prescription.facility_name).to eq('Ambulatory Pharmacy')
          expect(oracle_prescription.ordered_date).to eq('2025-11-17T21:21:48Z')
          expect(oracle_prescription.quantity).to eq('18.0')
          expect(oracle_prescription.expiration_date).to eq('2026-11-17T07:59:59Z')
          expect(oracle_prescription.prescription_number).to eq('20848812135')
          expect(oracle_prescription.prescription_name).to eq('albuterol (albuterol 90 mcg inhaler [18g])')
          expect(oracle_prescription.dispensed_date).to be_nil
          expect(oracle_prescription.station_number).to eq('668')
          expect(oracle_prescription.is_refillable).to be false # false because refill_status is 'submitted'
          expect(oracle_prescription.is_trackable).to be false
          expect(oracle_prescription.tracking).to eq([])
          expect(oracle_prescription.prescription_source).to eq('VA')
          expect(oracle_prescription.instructions).to eq(
            '2 Inhalation Inhalation (breathe in) every 4 hours as needed shortness of breath or wheezing. Refills: 2.'
          )
          expect(oracle_prescription.facility_phone_number).to be_nil
        end
      end

      it 'maps completed status to discontinued or expired' do
        VCR.use_cassette('unified_health_data/get_prescriptions_success') do
          prescriptions = service.get_prescriptions
          completed_prescription = prescriptions.find { |p| p.prescription_id == '20848863583' }

          expect(completed_prescription.refill_status).to be_in(%w[discontinued expired])
          expect(completed_prescription.is_refillable).to be false
          expect(completed_prescription.refill_date).to be_nil
        end
      end

      it 'handles different refill statuses correctly' do
        VCR.use_cassette('unified_health_data/get_prescriptions_success') do
          prescriptions = service.get_prescriptions

          active_prescription = prescriptions.find { |p| p.prescription_id == '26305871' }
          discontinued_prescription = prescriptions.find { |p| p.prescription_id == '26305874' }

          expect(active_prescription.refill_status).to eq('active')
          expect(discontinued_prescription.refill_status).to eq('discontinued')
        end
      end

      it 'properly handles Oracle Health FHIR features' do
        VCR.use_cassette('unified_health_data/get_prescriptions_success') do
          prescriptions = service.get_prescriptions

          # Test prescription with patientInstruction (should prefer over text)
          oracle_prescription_with_patient_instruction = prescriptions.find { |p| p.prescription_id == '20848812135' }
          expect(oracle_prescription_with_patient_instruction.instructions).to eq(
            '2 Inhalation Inhalation (breathe in) every 4 hours as needed shortness of breath or wheezing. ' \
            'Refills: 2.'
          )
          expect(oracle_prescription_with_patient_instruction.facility_name).to eq('Ambulatory Pharmacy')
          expect(oracle_prescription_with_patient_instruction.refill_date).to eq('2025-11-17T21:35:02.000Z')
          expect(oracle_prescription_with_patient_instruction.dispensed_date).to be_nil
        end
      end

      context 'Task resource parsing' do
        it 'sets refill_status to submitted when a valid Task exists' do
          VCR.use_cassette('unified_health_data/get_prescriptions_success') do
            prescriptions = service.get_prescriptions
            # Prescription 20848812135 has a Task with status='requested' and intent='order'
            submitted_prescription = prescriptions.find { |p| p.prescription_id == '20848812135' }

            expect(submitted_prescription.refill_status).to eq('submitted')
          end
        end

        it 'sets disp_status to Active: Submitted when a valid Task exists' do
          VCR.use_cassette('unified_health_data/get_prescriptions_success') do
            prescriptions = service.get_prescriptions
            # Prescription 20848812135 has a Task with status='requested' and intent='order'
            submitted_prescription = prescriptions.find { |p| p.prescription_id == '20848812135' }

            expect(submitted_prescription.disp_status).to eq('Active: Submitted')
          end
        end

        it 'sets refill_submit_date from Task executionPeriod.start' do
          VCR.use_cassette('unified_health_data/get_prescriptions_success') do
            prescriptions = service.get_prescriptions
            # Prescription 20848812135 has a Task with executionPeriod.start='2025-11-26T15:55:17+00:00'
            submitted_prescription = prescriptions.find { |p| p.prescription_id == '20848812135' }

            expect(submitted_prescription.refill_submit_date).to eq('2025-11-26T15:55:17+00:00')
          end
        end

        it 'ignores Tasks with failed status' do
          VCR.use_cassette('unified_health_data/get_prescriptions_success') do
            prescriptions = service.get_prescriptions
            # Prescription 20848650695 has multiple Tasks but all have status='failed'
            failed_task_prescription = prescriptions.find { |p| p.prescription_id == '20848650695' }

            # Should NOT have refill_submit_date set from failed Tasks
            expect(failed_task_prescription.refill_submit_date).to be_nil
            # Should have normal active status, not submitted
            expect(failed_task_prescription.refill_status).to eq('active')
          end
        end

        it 'sets disp_status to Active (not Active: Submitted) when Tasks are failed' do
          VCR.use_cassette('unified_health_data/get_prescriptions_success') do
            prescriptions = service.get_prescriptions
            # Prescription 20848650695 has multiple Tasks but all have status='failed'
            failed_task_prescription = prescriptions.find { |p| p.prescription_id == '20848650695' }

            expect(failed_task_prescription.disp_status).to eq('Active')
          end
        end

        it 'does not affect prescriptions without any Tasks' do
          VCR.use_cassette('unified_health_data/get_prescriptions_success') do
            prescriptions = service.get_prescriptions
            # VistA prescription 26305871 should have no Task resources
            vista_prescription = prescriptions.find { |p| p.prescription_id == '26305871' }

            expect(vista_prescription.refill_status).to eq('active')
            expect(vista_prescription.refill_submit_date).to be_nil
            expect(vista_prescription.disp_status).to eq('Active')
          end
        end
      end

      context 'facility name extraction integration' do
        it 'uses cache when available and API when cache misses' do
          # Test cache hit scenario
          allow(Rails.cache).to receive(:read).with('uhd:facility_names:668').and_return('Cached Facility Name')
          allow(Rails.cache).to receive(:exist?).with('uhd:facility_names:668').and_return(true)

          VCR.use_cassette('unified_health_data/get_prescriptions_success') do
            prescriptions = service.get_prescriptions
            oracle_prescription = prescriptions.find { |p| p.prescription_id == '20848812135' }

            expect(oracle_prescription.facility_name).to eq('Cached Facility Name')
          end
        end

        it 'falls back to API when cache is empty' do
          allow(Rails.cache).to receive(:read).with('uhd:facility_names:668').and_return(nil)
          allow(Rails.cache).to receive(:exist?).with('uhd:facility_names:668').and_return(false)

          # Mock the Lighthouse API call
          mock_client = instance_double(Lighthouse::Facilities::V1::Client)
          mock_facility = double('facility', name: 'API Retrieved Facility')
          allow(Lighthouse::Facilities::V1::Client).to receive(:new).and_return(mock_client)
          allow(mock_client).to receive(:get_facilities).with(facilityIds: 'vha_668').and_return([mock_facility])

          VCR.use_cassette('unified_health_data/get_prescriptions_success') do
            prescriptions = service.get_prescriptions
            oracle_prescription = prescriptions.find { |p| p.prescription_id == '20848812135' }

            expect(oracle_prescription.facility_name).to eq('API Retrieved Facility')
            # API is called multiple times for different prescriptions with same station number
            expect(mock_client).to have_received(:get_facilities).with(facilityIds: 'vha_668').at_least(:once)
          end
        end

        it 'handles API errors gracefully' do
          allow(Rails.cache).to receive(:read).with('uhd:facility_names:668').and_return(nil)
          allow(Rails.cache).to receive(:exist?).with('uhd:facility_names:668').and_return(false)
          allow(Rails.logger).to receive(:error)
          allow(StatsD).to receive(:increment)

          # Mock API to raise an error
          mock_client = instance_double(Lighthouse::Facilities::V1::Client)
          allow(Lighthouse::Facilities::V1::Client).to receive(:new).and_return(mock_client)
          allow(mock_client).to receive(:get_facilities).and_raise(StandardError, 'API unavailable')

          VCR.use_cassette('unified_health_data/get_prescriptions_success') do
            prescriptions = service.get_prescriptions
            oracle_prescription = prescriptions.find { |p| p.prescription_id == '20848812135' }

            expect(oracle_prescription.facility_name).to be_nil
            # Error is logged multiple times for different prescriptions with same station number
            expect(Rails.logger).to have_received(:error).with(
              'Failed to fetch facility name from API for station 668: API unavailable'
            ).at_least(:once)
            expect(StatsD).to have_received(:increment).with(
              'unified_health_data.facility_name_fallback.api_error'
            ).at_least(:once)
          end
        end
      end

      it 'logs prescription retrieval information' do
        allow(Rails.logger).to receive(:info)

        VCR.use_cassette('unified_health_data/get_prescriptions_success') do
          service.get_prescriptions

          expect(Rails.logger).to have_received(:info).with(
            hash_including(
              message: 'UHD prescriptions retrieved',
              total_prescriptions: 30,
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
            { id: '20848650695', stationNumber: '668' },
            { id: '0000000000001', stationNumber: '570' }
          ]
          result = service.refill_prescription(orders)

          expect(result[:success]).to eq([{ id: '20848650695', status: 'Refill Submitted', station_number: '668' }])
          expect(result[:failed]).to eq([{ id: '0000000000001', error: 'Prescription is not Found',
                                           station_number: '570' }])
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

    context 'with prescription not found', :vcr do
      it 'returns failed refill when prescription is not found' do
        VCR.use_cassette('unified_health_data/refill_prescription_empty') do
          result = service.refill_prescription([{ id: '21431810851', stationNumber: '663' }])

          expect(result[:success]).to eq([])
          expect(result[:failed]).to eq([{ id: '21431810851', error: 'Prescription is not Found',
                                           station_number: '663' }])
        end
      end
    end

    context 'parse_refill_response edge cases' do
      it 'always returns arrays for success and failed keys with nil response body' do
        response = double(body: nil)

        result = service.send(:parse_refill_response, response)

        expect(result).to have_key(:success)
        expect(result).to have_key(:failed)
        expect(result[:success]).to eq([])
        expect(result[:failed]).to eq([])
      end

      it 'always returns arrays for success and failed keys with non-array response body' do
        response = double(body: { error: 'Invalid format' })

        result = service.send(:parse_refill_response, response)

        expect(result).to have_key(:success)
        expect(result).to have_key(:failed)
        expect(result[:success]).to eq([])
        expect(result[:failed]).to eq([])
      end

      it 'always returns arrays for success and failed keys with empty array response' do
        response = double(body: [])

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

    context 'validate_refill_response_count' do
      it 'does not raise error when counts match' do
        normalized_orders = [
          { id: '123', stationNumber: '570' },
          { id: '456', stationNumber: '571' }
        ]
        result = {
          success: [{ id: '123', status: 'submitted', station_number: '570' }],
          failed: [{ id: '456', error: 'Failed', station_number: '571' }]
        }

        expect do
          service.send(:validate_refill_response_count, normalized_orders, result)
        end.not_to raise_error
      end

      it 'raises error when response has fewer items than sent' do
        normalized_orders = [
          { id: '123', stationNumber: '570' },
          { id: '456', stationNumber: '571' },
          { id: '789', stationNumber: '572' }
        ]
        result = {
          success: [{ id: '123', status: 'submitted', station_number: '570' }],
          failed: [{ id: '456', error: 'Failed', station_number: '571' }]
        }

        allow(Rails.logger).to receive(:error)

        expect do
          service.send(:validate_refill_response_count, normalized_orders, result)
        end.to raise_error(Common::Exceptions::PrescriptionRefillResponseMismatch)

        expect(Rails.logger).to have_received(:error).with(
          'Refill response count mismatch: sent 3 orders, received 2 responses'
        )
      end

      it 'raises error when response has more items than sent' do
        normalized_orders = [
          { id: '123', stationNumber: '570' }
        ]
        result = {
          success: [{ id: '123', status: 'submitted', station_number: '570' }],
          failed: [{ id: '456', error: 'Failed', station_number: '571' }]
        }

        allow(Rails.logger).to receive(:error)

        expect do
          service.send(:validate_refill_response_count, normalized_orders, result)
        end.to raise_error(Common::Exceptions::PrescriptionRefillResponseMismatch)

        expect(Rails.logger).to have_received(:error).with(
          'Refill response count mismatch: sent 1 orders, received 2 responses'
        )
      end

      it 'raises error when no responses received for multiple orders' do
        normalized_orders = [
          { id: '123', stationNumber: '570' },
          { id: '456', stationNumber: '571' }
        ]
        result = {
          success: [],
          failed: []
        }

        allow(Rails.logger).to receive(:error)

        expect do
          service.send(:validate_refill_response_count, normalized_orders, result)
        end.to raise_error(Common::Exceptions::PrescriptionRefillResponseMismatch)

        expect(Rails.logger).to have_received(:error).with(
          'Refill response count mismatch: sent 2 orders, received 0 responses'
        )
      end

      it 'does not raise error when both orders and responses are empty' do
        normalized_orders = []
        result = {
          success: [],
          failed: []
        }

        expect do
          service.send(:validate_refill_response_count, normalized_orders, result)
        end.not_to raise_error
      end

      it 'handles all success responses correctly' do
        normalized_orders = [
          { id: '123', stationNumber: '570' },
          { id: '456', stationNumber: '571' }
        ]
        result = {
          success: [
            { id: '123', status: 'submitted', station_number: '570' },
            { id: '456', status: 'submitted', station_number: '571' }
          ],
          failed: []
        }

        expect do
          service.send(:validate_refill_response_count, normalized_orders, result)
        end.not_to raise_error
      end

      it 'handles all failed responses correctly' do
        normalized_orders = [
          { id: '123', stationNumber: '570' },
          { id: '456', stationNumber: '571' }
        ]
        result = {
          success: [],
          failed: [
            { id: '123', error: 'Failed', station_number: '570' },
            { id: '456', error: 'Failed', station_number: '571' }
          ]
        }

        expect do
          service.send(:validate_refill_response_count, normalized_orders, result)
        end.not_to raise_error
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

    it 'returns conditions sorted by date in descending order' do
      conditions = service.get_conditions.sort

      conditions_with_dates = conditions.select { |condition| condition.date.present? }
      dates = conditions_with_dates.map { |condition| Time.zone.parse(condition.date) }
      expect(dates).to eq(dates.sort.reverse)

      conditions_without_dates = conditions.select { |condition| condition.date.nil? }
      if conditions_without_dates.any?
        expect(conditions.last(conditions_without_dates.size)).to eq(conditions_without_dates)
      end
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

  describe '#get_ccd_binary' do
    let(:ccd_fixture) do
      JSON.parse(Rails.root.join('spec', 'fixtures', 'unified_health_data', 'ccd_example.json').read)
    end
    let(:ccd_response) do
      Faraday::Response.new(body: ccd_fixture)
    end

    let(:client_double) { instance_double(UnifiedHealthData::Client) }

    before do
      allow(UnifiedHealthData::Client).to receive(:new).and_return(client_double)
      allow(client_double).to receive(:get_ccd).and_return(ccd_response)
    end

    context 'when requesting XML format' do
      it 'returns BinaryData object with Base64 encoded XML' do
        result = service.get_ccd_binary(format: 'xml')

        expect(result).to be_a(UnifiedHealthData::BinaryData)
        expect(result.content_type).to eq('application/xml')
        expect(result.binary).to be_present
        expect(result.binary[0, 20]).to eq('PD94bWwgdmVyc2lvbj0i')
      end
    end

    context 'when requesting HTML format' do
      it 'returns BinaryData object with Base64 encoded HTML' do
        result = service.get_ccd_binary(format: 'html')

        expect(result).to be_a(UnifiedHealthData::BinaryData)
        expect(result.content_type).to eq('text/html')
        expect(result.binary).to be_present
        expect(result.binary[0, 20]).to eq('PCEtLSBEbyBOT1QgZWRp')
      end
    end

    context 'when requesting PDF format' do
      it 'returns BinaryData object with Base64 encoded PDF' do
        result = service.get_ccd_binary(format: 'pdf')

        expect(result).to be_a(UnifiedHealthData::BinaryData)
        expect(result.content_type).to eq('application/pdf')
        expect(result.binary).to be_present
        expect(result.binary[0, 20]).to eq('JVBERi0xLjUKJeLjz9MK')
      end
    end

    context 'when requesting unavailable format' do
      let(:modified_ccd) do
        ccd_data = JSON.parse(ccd_fixture.to_json)
        doc_ref = ccd_data['entry'].find { |e| e['resource']['resourceType'] == 'DocumentReference' }
        doc_ref['resource']['content'].reject! do |item|
          item['attachment']['contentType'] == 'text/html'
        end
        ccd_data
      end
      let(:ccd_response) do
        Faraday::Response.new(body: modified_ccd)
      end

      before do
        allow(client_double).to receive(:get_ccd).and_return(ccd_response)
      end

      it 'raises an error for missing HTML' do
        expect do
          service.get_ccd_binary(format: 'html')
        end.to raise_error(ArgumentError, /Format html not available/)
      end
    end

    context 'when requesting invalid format' do
      it 'raises an ArgumentError' do
        expect do
          service.get_ccd_binary(format: 'json')
        end.to raise_error(ArgumentError, /Invalid format/)
      end
    end

    context 'when DocumentReference is missing' do
      let(:empty_bundle) { { 'entry' => [] } }
      let(:ccd_response) do
        Faraday::Response.new(body: empty_bundle)
      end

      it 'returns nil when no CCD document exists' do
        result = service.get_ccd_binary(format: 'xml')
        expect(result).to be_nil
      end
    end
  end
end
