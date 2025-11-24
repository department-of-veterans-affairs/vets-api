# frozen_string_literal: true

require 'rails_helper'
require 'pdf_fill/forms/va220803'

describe PdfFill::Forms::Va220803 do
  subject { described_class.new(form_data) }

  let(:form_data) do
    JSON.parse(Rails.root.join('spec', 'fixtures', 'education_benefits_claims', '0803', 'minimal.json').read)
  end

  describe '#merge_fields' do
    let(:merged_fields) { subject.merge_fields }

    it 'formats the applicant name correctly' do
      merged_data = subject.merge_fields

      expect(merged_data['applicantName']).to eq('John Smith')
    end

    it 'formats the mailing address correctly' do
      merged_data = subject.merge_fields

      expect(merged_data['mailingAddress']).to eq("123 Maple Ln\nHamilton, IA, 12345\nUSA")
    end

    it 'formats the bill type correctly' do
      merged_data = subject.merge_fields

      expect(merged_data['bill_type_chapter_30']).to eq(nil)
      expect(merged_data['bill_type_chapter_33']).to eq(nil)
      expect(merged_data['bill_type_chapter_35']).to eq('Yes')
      expect(merged_data['bill_type_chapter_1606']).to eq(nil)
    end
    
    it 'formats the file number correctly' do
      merged_data = subject.merge_fields

      expect(merged_data['fileNumber']).to eq('123456789:AB')
    end
    
    it 'formats the file organization info correctly' do
      merged_data = subject.merge_fields

      expect(merged_data['organizationInfo']).to eq("Acme Co.\n123 Fake St\nTulsa, OK, 23456\nUSA\n")
    end
  end
end
