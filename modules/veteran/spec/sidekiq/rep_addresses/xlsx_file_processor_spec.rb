# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RepAddresses::XlsxFileProcessor do
  let(:mock_file_content) { File.read('modules/veteran/spec/fixtures/xlsx_files/rep-mock-data.xlsx') }
  let(:xlsx_processor) { described_class.new(mock_file_content) }

  def check_values(hash)
    invalid_values = ['', 'NULL', 'null']

    hash.each do |_key, value|
      if value.is_a?(String)
        expect(invalid_values).not_to include(value)
      elsif value.is_a?(Hash)
        check_values(value)
      end
    end
  end

  describe '#process' do
    let(:result) { xlsx_processor.process }

    context 'with valid data' do
      let(:expected_keys) { %w[id type email_address request_address] }
      let(:request_address_keys) do
        %w[address_pou address_line1 address_line2 address_line3 city state_province zip_code5 zip_code4
           country_code_iso3]
      end

      it 'processes the file and validates the data structure and content' do
        expect(result).to be_a(Hash)
        expect(result.keys).to include('Attorneys', 'Representatives')

        result.each do |_key, value_array|
          expect(value_array).to all(be_a(String))

          value_array.each do |json_string|
            json_object = JSON.parse(json_string)
            expect(json_object.keys).to match_array(expected_keys)
            expect(json_object['request_address'].keys).to match_array(request_address_keys)
            check_values(json_object)
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
        allow(xlsx_processor).to receive(:log_message_to_sentry)
      end

      it 'rescues the error and logs it to Sentry' do
        expect { xlsx_processor.process }.not_to raise_error
        expected_log_message = "XlsxFileProcessor error: Error processing XLSX file: #{error_message}"
        expect(xlsx_processor).to have_received(:log_message_to_sentry).with(expected_log_message, :error)
      end
    end
  end
end
