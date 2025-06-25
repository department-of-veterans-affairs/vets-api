# frozen_string_literal: true

require 'rails_helper'
require 'pdf_fill/forms/va2210215a'

describe PdfFill::Forms::Va2210215a do
  let(:form_data) do
    {
      'certifyingOfficial' => {
        'first' => 'John',
        'last' => 'Doe'
      },
      'institutionDetails' => {
        'dateOfCalculations' => '2024-01-01'
      },
      'programs' => [
        {
          'fte' => {
            'supportedPercentageFTE' => 85
          }
        }
      ]
    }
  end

  let(:options) do
    {
      page_number: 2,
      total_pages: 5
    }
  end

  subject { described_class.new(form_data) }

  describe '#merge_fields' do
    it 'merges the fields correctly' do
      merged_data = subject.merge_fields(options)

      # Test certifying official's full name
      expect(merged_data['certifyingOfficial']['fullName']).to eq('John Doe')

      # Test program data processing
      expect(merged_data['programs'].first['programDateOfCalculation']).to eq('2024-01-01')
      expect(merged_data['programs'].first['fte']['supportedPercentageFTE']).to eq('85%')

      # Test page numbering
      expect(merged_data['pageNumber']).to eq('2')
      expect(merged_data['totalPages']).to eq('5')
    end

    it 'handles missing names gracefully' do
      form_data['certifyingOfficial'] = { 'first' => 'John' }
      merged_data = subject.merge_fields(options)
      expect(merged_data['certifyingOfficial']['fullName']).to be_nil
    end

    it 'handles default page numbers' do
      merged_data = subject.merge_fields # No options hash
      expect(merged_data['pageNumber']).to eq('1')
      expect(merged_data['totalPages']).to eq('1')
    end
  end
end
