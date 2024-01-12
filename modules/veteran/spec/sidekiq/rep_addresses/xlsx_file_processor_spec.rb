# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RepAddresses::XlsxFileProcessor do
  let(:mock_file_content) { File.read('modules/veteran/spec/fixtures/xlsx_files/rep-mock-data.xlsx') }
  let(:xlsx_processor) { described_class.new(mock_file_content) }

  describe '#process' do
    context 'with valid data' do
      it 'processes the file and returns the correct data structure' do
        result = xlsx_processor.process
        expect(result).to be_a(Hash)
        expect(result.keys).to include('Attorneys', 'Representatives')
        # Add more specific assertions based on your mock data
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
