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
    context 'with valid data' do
      it 'processes the file and returns the correct data structure' do
        result = xlsx_processor.process
        expect(result).to be_a(Hash)
        expect(result.keys).to include('Attorneys', 'Representatives')
      end

      it 'processes the file and returns the correct data structure with expected keys in each JSON object' do
        result = xlsx_processor.process
        expected_keys = %w[id type email_address request_address]

        result.each do |_key, value_array|
          expect(value_array).to all(be_a(String))

          value_array.each do |json_string|
            json_object = JSON.parse(json_string)
            # Checks the first level of keys in the JSON object
            expect(json_object.keys).to match_array(expected_keys)

            request_address_keys = %w[address_pou address_line1 address_line2 address_line3 city state_province
                                      zip_code5 zip_code4 country_code_iso3]
            # Checks the 'request_address' keys in the JSON object
            expect(json_object['request_address'].keys).to match_array(request_address_keys)
          end
        end
      end

      it 'ensures no fields contain "NULL", "null", or an empty string' do # rubocop:disable RSpec/NoExpectationExample
        result = xlsx_processor.process

        result.each do |_, value_array|
          value_array.each do |json_string|
            json_object = JSON.parse(json_string)
            check_values(json_object)
          end
        end
      end
    end

    context 'with an invalid file' do
      let(:invalid_file_content) { 'invalid content' }
      let(:xlsx_processor) { described_class.new(invalid_file_content) }

      it 'logs an error' do
        expect { xlsx_processor.process }.not_to raise_error
        # Check if an error was logged, or if the result is as expected in case of an error
      end
    end
  end
end
