# frozen_string_literal: true

require 'rails_helper'

def basic_class
  DependentsVerification::PdfFill::Va210538.new({})
end

describe DependentsVerification::PdfFill::Va210538 do
  let(:form_data) do
    {}
  end

  let(:new_form_class) do
    described_class.new(form_data)
  end

  let(:path) { 'modules/dependents_verification/lib/dependents_verification/pdf_fill/pdfs/21-0538.pdf' }
  let :fields do
    def get_keys(hash)
      hash.map do |key, value|
        if value.has_key?(:key)
          value[:key]
        elsif value.is_a?(Hash)
          get_keys(value)
        end
      end
    end
    get_keys(described_class::KEY).flatten.compact
  end

  def class_form_data
    new_form_class.instance_variable_get(:@form_data)
  end

  describe '#merge_fields' do
    it 'merges the right fields', run_at: '2024-03-21 00:00:00 EDT' do
      actual = File.read("#{DependentsVerification::MODULE_PATH}/spec/fixtures/pdf_fill/21-0538/kitchen_sink.json")
      expected = File.read("#{DependentsVerification::MODULE_PATH}/spec/fixtures/pdf_fill/21-0538/merge_fields.json")
      expect(described_class.new(JSON.parse(actual)).merge_fields.to_json).to eq(JSON.parse(expected).to_json)
    end
  end

  it 'includes all expected fields in the PDF, even if there are extras' do
    pdf = PdfForms.new(Settings.binaries.pdftk)
    fields_in_pdf = pdf.get_fields(path).map(&:name)
    expect(fields_in_pdf).to include(*fields)
  end

  it 'does not have duplicate field names in the PDF' do
    pdf = PdfForms.new(Settings.binaries.pdftk)
    fields_in_pdf = pdf.get_fields(path).map(&:name)
    expect(fields_in_pdf.uniq.size).to eq(fields_in_pdf.size)
  end
end
