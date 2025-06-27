# frozen_string_literal: true

require 'rails_helper'
require 'pdf_fill/forms/va2210215'

describe PdfFill::Forms::Va2210215 do
  subject { described_class.new(form_data) }

  let(:form_data) do
    {
      'certifyingOfficial' => {
        'first' => 'Jane',
        'last' => 'Doe'
      },
      'institutionDetails' => {
        'dateOfCalculations' => '2024-02-01'
      },
      'programs' => [{ 'name' => 'My Program' }]
    }
  end

  describe '#merge_fields' do
    it 'merges the certifying official and program data correctly' do
      merged_data = subject.merge_fields

      expect(merged_data['certifyingOfficial']['fullName']).to eq('Jane Doe')
      expect(merged_data['programs'].first['programDateOfCalculation']).to eq('2024-02-01')
    end

    it 'handles missing certifying official name parts gracefully' do
      form_data['certifyingOfficial'] = { 'first' => 'Jane' }
      merged_data = subject.merge_fields
      expect(merged_data['certifyingOfficial']['fullName']).to be_nil
    end

    it 'does not error if certifyingOfficial key is missing' do
      form_data.delete('certifyingOfficial')
      expect { subject.merge_fields }.not_to raise_error
    end

    it 'does not error if institutionDetails key is missing' do
      form_data.delete('institutionDetails')
      merged_data = subject.merge_fields
      expect(merged_data['programs'].first['programDateOfCalculation']).to be_nil
    end

    it 'does not error if programs key is missing' do
      form_data.delete('programs')
      expect { subject.merge_fields }.not_to raise_error
    end
  end
end
