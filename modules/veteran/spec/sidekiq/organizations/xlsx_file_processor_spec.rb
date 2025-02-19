# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Organizations::XlsxFileProcessor do
  let(:mock_file_content) { File.read('modules/veteran/spec/fixtures/xlsx_files/rep-mock-data.xlsx') }
  let(:xlsx_processor) { described_class.new(mock_file_content) }

  def check_values(hash)
    invalid_values = ['', 'null']

    hash.each do |key, value|
      if value.is_a?(String)
        expect(invalid_values).not_to include(value.downcase)
        expect(value).to match(/\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i) if key == 'email_address'
      elsif value.is_a?(Hash)
        check_values(value)
      end
    end
  end

  describe '#process' do
    let(:result) { xlsx_processor.process }

    context 'with valid data' do
      let(:expected_keys) { %i[id address phone_number] }
      let(:expected_address_keys) do
        %i[address_pou address_line1 address_line2 address_line3 city state zip_code5 zip_code4
           country_code_iso3]
      end

      it 'processes the file and validates the data structure and content' do
        expect(result).to be_a(Hash)
        expect(result.keys).to include('VSOs')

        result.each_value do |value_array|
          expect(value_array).to all(be_a(Hash))

          value_array.each do |row|
            expect(row.keys).to match_array(expected_keys)
            expect(row[:address].keys).to match_array(expected_address_keys)
            check_values(row)
          end
        end
      end
    end

    context 'when an error occurs opening the spreadsheet' do
      let(:invalid_file_content) { 'invalid content' }
      let(:xlsx_processor) { described_class.new(invalid_file_content) }
      let(:error_message) { 'Mocked Roo error' }

      before do
        allow(Roo::Spreadsheet).to receive(:open).and_raise(Roo::Error.new(error_message))
        allow(xlsx_processor).to receive(:log_error)
      end

      it 'logs the error when opening the spreadsheet fails' do
        expect { xlsx_processor.process }.not_to raise_error
        expected_log_message = "Error opening spreadsheet: #{error_message}"
        expect(xlsx_processor).to have_received(:log_error).with(expected_log_message)
      end
    end

    context 'when an error occurs during processing' do
      let(:error_message) { 'test error' }

      before do
        allow(Roo::Spreadsheet).to receive(:open).and_raise(StandardError.new(error_message))
        allow(Rails.logger).to receive(:error)
      end

      it 'rescues the error and logs it to Rails.logger.error' do
        expect { xlsx_processor.process }.not_to raise_error
        expected_log_message = "XlsxFileProcessor error: Error processing XLSX file: #{error_message}"
        expect(Rails.logger).to have_received(:error).with(expected_log_message)
      end
    end

    context 'with state code validation' do
      it 'processes only rows with valid state codes' do
        valid_states = Representatives::XlsxFileProcessor::US_STATES_TERRITORIES

        result.each_value do |value_array|
          value_array.each do |row|
            state_code = row.dig('request_address', 'state_province', 'code')

            expect(valid_states).to include(state_code) unless state_code.nil?
          end
        end
      end
    end
  end
end
