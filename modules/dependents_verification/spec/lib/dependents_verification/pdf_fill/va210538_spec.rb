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
  let(:fields) do
    %w[
      SectionI1.VeteransName.First SectionI1.VeteransName.Last SectionI1.VeteransName.MI
      SectionI2.VeteranSSN.First SectionI2.VeteranSSN.Middle SectionI2.VeteranSSN.Last
      SectionI3.VeteranFileNumber SectionI4.VeteranDOB.Month SectionI4.VeteranDOB.Day SectionI4.VeteranDOB.Year
      SectionI5.VeteranAddress.Street SectionI5.VeteranAddress.City SectionI5.VeteranAddress.UnitNumber
      SectionI5.VeteranAddress.Country SectionI5.VeteranAddress.State SectionI5.VeteranAddress.PostalCode.First
      SectionI5.VeteranAddress.PostalCode.Second SectionI6.VeteranPhone.First SectionI6.VeteranPhone.Second
      SectionI6.VeteranPhone.Third SectionI7.VeteranEmail.Second SectionI7.VeteranEmail.First
      SectionI7.VeteranEmail.Agree SectionII8.StatusChange V14.SignatureField V14.SignatureDate.Month
      V14.SignatureDate.Day V14.SignatureDate.Year VaDateStamp
    ]
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
