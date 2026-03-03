# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RepresentationManagement::XlsxFileProcessor do
  let(:fixture_path) { 'modules/representation_management/spec/fixtures/xlsx_files/rep-mock-data.xlsx' }
  let(:mock_file_content) { File.read(fixture_path) }

  describe '#process' do
    context 'with all types' do
      subject { described_class.new(mock_file_content) }

      let(:result) { subject.process }

      it 'processes all sheets' do
        expect(result.keys).to match_array(%w[attorney claims_agent representative organization])
      end

      it 'returns a hash' do
        expect(result).to be_a(Hash)
      end
    end

    context 'with filtered types' do
      subject { described_class.new(mock_file_content, ['attorney']) }

      let(:result) { subject.process }

      it 'only processes specified types' do
        expect(result.keys).to eq(['attorney'])
        expect(result).not_to have_key('organization')
        expect(result).not_to have_key('claims_agent')
        expect(result).not_to have_key('representative')
      end
    end

    context 'individual sheet processing' do
      subject { described_class.new(mock_file_content, ['attorney']) }

      let(:result) { subject.process }
      let(:expected_keys) { %i[ogc_id registration_number individual_type email phone_number address raw_address] }

      it 'returns records with required keys' do
        attorneys = result['attorney']
        expect(attorneys).to be_present

        attorneys.each do |record|
          expect(record.keys).to match_array(expected_keys)
        end
      end

      it 'sets individual_type correctly' do
        result['attorney'].each do |record|
          expect(record[:individual_type]).to eq('attorney')
        end
      end

      it 'includes ogc_id as a UUID' do
        result['attorney'].each do |record|
          expect(record[:ogc_id]).to match(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i)
        end
      end

      it 'builds raw_address with string keys' do
        result['attorney'].each do |record|
          raw_address = record[:raw_address]
          expect(raw_address).to be_a(Hash)
          expect(raw_address.keys).to all(be_a(String))
          expect(raw_address).to have_key('address_line1')
          expect(raw_address).to have_key('city')
          expect(raw_address).to have_key('state_code')
          expect(raw_address).to have_key('zip_code')
        end
      end

      it 'includes address with expected structure' do
        expected_address_keys = %i[address_pou address_line1 address_line2 address_line3
                                   city state zip_code5 zip_code4 country_code_iso3]

        result['attorney'].each do |record|
          expect(record[:address].keys).to match_array(expected_address_keys)
          expect(record[:address][:address_pou]).to eq('RESIDENCE')
          expect(record[:address][:country_code_iso3]).to eq('US')
        end
      end
    end

    context 'claims agent processing' do
      subject { described_class.new(mock_file_content, ['claims_agent']) }

      let(:result) { subject.process }

      it 'processes the Agents sheet' do
        agents = result['claims_agent']
        expect(agents).to be_present
      end

      it 'sets individual_type to claims_agent' do
        result['claims_agent'].each do |record|
          expect(record[:individual_type]).to eq('claims_agent')
        end
      end
    end

    context 'representative processing' do
      subject { described_class.new(mock_file_content, ['representative']) }

      let(:result) { subject.process }

      it 'processes the Representatives sheet' do
        reps = result['representative']
        expect(reps).to be_present
      end

      it 'sets individual_type to representative' do
        result['representative'].each do |record|
          expect(record[:individual_type]).to eq('representative')
        end
      end
    end

    context 'organization sheet processing' do
      subject { described_class.new(mock_file_content, ['organization']) }

      let(:result) { subject.process }
      let(:expected_keys) { %i[ogc_id poa_code name phone address raw_address] }

      it 'returns records with required keys' do
        orgs = result['organization']
        expect(orgs).to be_present

        orgs.each do |record|
          expect(record.keys).to match_array(expected_keys)
        end
      end

      it 'builds raw_address with string keys' do
        result['organization'].each do |record|
          raw_address = record[:raw_address]
          expect(raw_address).to be_a(Hash)
          expect(raw_address.keys).to all(be_a(String))
        end
      end

      it 'includes address with CORRESPONDENCE pou' do
        result['organization'].each do |record|
          expect(record[:address][:address_pou]).to eq('CORRESPONDENCE')
        end
      end

      it 'includes ogc_id as a UUID' do
        result['organization'].each do |record|
          expect(record[:ogc_id]).to match(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i)
        end
      end
    end

    context 'US state filtering' do
      subject { described_class.new(mock_file_content) }

      let(:result) { subject.process }

      it 'only includes records from US states and territories' do
        result.each_value do |records|
          records.each do |record|
            state = record.dig(:raw_address, 'state_code')
            next unless state

            expect(described_class::US_STATES_TERRITORIES).to have_key(state)
          end
        end
      end
    end

    context 'deduplication' do
      subject { described_class.new(mock_file_content, ['representative']) }

      let(:result) { subject.process }

      it 'deduplicates individual records by registration number' do
        reps = result['representative']
        registration_numbers = reps.map { |r| r[:registration_number] }
        expect(registration_numbers).to eq(registration_numbers.uniq)
      end
    end

    context 'organization deduplication' do
      subject { described_class.new(mock_file_content, ['organization']) }

      let(:result) { subject.process }

      it 'deduplicates organization records by poa_code' do
        orgs = result['organization']
        poa_codes = orgs.map { |r| r[:poa_code] }
        expect(poa_codes).to eq(poa_codes.uniq)
      end
    end

    context 'with invalid file content' do
      subject { described_class.new('not a valid xlsx file') }

      it 'returns empty hash on error' do
        result = subject.process
        expect(result).to eq({})
      end

      it 'logs the error' do
        expect(Rails.logger).to receive(:error).with(/XlsxFileProcessor error/)
        subject.process
      end
    end

    context 'zip code formatting' do
      subject { described_class.new(mock_file_content, ['attorney']) }

      let(:result) { subject.process }

      it 'formats zip codes correctly' do
        result['attorney'].each do |record|
          zip = record.dig(:raw_address, 'zip_code')
          next unless zip

          if zip.include?('-')
            zip5, zip4 = zip.split('-')
            expect(zip5.length).to eq(5)
            expect(zip4.length).to eq(4)
          else
            expect(zip.length).to eq(5)
          end
        end
      end
    end

    context 'email validation' do
      subject { described_class.new(mock_file_content, ['attorney']) }

      let(:result) { subject.process }

      it 'only includes valid emails' do
        result['attorney'].each do |record|
          next unless record[:email]

          expect(record[:email]).to match(/\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i)
        end
      end
    end

    context 'null value handling' do
      subject { described_class.new(mock_file_content) }

      let(:result) { subject.process }

      it 'converts blank and null strings to nil' do
        result.each_value do |records|
          records.each do |record|
            record.each_value do |value|
              next unless value.is_a?(String)

              expect(value.downcase).not_to eq('null')
              expect(value).not_to be_empty
            end
          end
        end
      end
    end

    context 'when an error occurs opening the spreadsheet' do
      let(:error_message) { 'Mocked Roo error' }

      before do
        allow(Roo::Spreadsheet).to receive(:open).and_raise(Roo::Error.new(error_message))
      end

      it 'handles the error gracefully' do
        processor = described_class.new('some content')
        result = processor.process
        expect(result).to eq({})
      end
    end
  end
end
