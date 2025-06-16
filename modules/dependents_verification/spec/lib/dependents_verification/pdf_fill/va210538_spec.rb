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
  let :keys do
    def get_keys(hash)
      hash.map do |key, value|
        if key == :key
          value
        elsif value.key?(:key)
          value[:key]
        elsif value.is_a?(Hash)
          get_keys(value)
        end
      end
    end
    get_keys(described_class::KEY).flatten.compact
  end

  let(:fields) do
    %w[
      Section0.0.VaDateStamp Section1.1.VeteranName.First Section1.1.VeteranName.Last Section1.1.VeteranName.MI
      Section1.2.VeteranSSN.First Section1.2.VeteranSSN.Middle Section1.2.VeteranSSN.Last
      Section1.3.VeteranFileNumber Section1.4.VeteranDOB.Month Section1.4.VeteranDOB.Day Section1.4.VeteranDOB.Year
      Section1.5.VeteranAddress.Street Section1.5.VeteranAddress.City Section1.5.VeteranAddress.UnitNumber
      Section1.5.VeteranAddress.Country Section1.5.VeteranAddress.State Section1.5.VeteranAddress.PostalCode.First
      Section1.5.VeteranAddress.PostalCode.Second Section1.6.VeteranPhone.First Section1.6.VeteranPhone.Second
      Section1.6.VeteranPhone.Third Section1.6.VeteranPhone.International Section1.7.VeteranEmail.Second
      Section1.7.VeteranEmail.First Section1.7.VeteranEmail.Agree Section2.8.StatusChange Section5.14.SignatureField
      Section5.14.SignatureDate.Month Section5.14.SignatureDate.Day Section5.14.SignatureDate.Year
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

  describe 'template pdf' do
    let(:pdf_keys) do
      pdf = PdfForms.new(Settings.binaries.pdftk)
      pdf.get_fields(path).map(&:name)
    end

    it 'includes all mapped keys' do
      expect(pdf_keys).to include(*keys)
    end

    it 'includes all documented fields' do
      expect(pdf_keys).to include(*fields)
    end

    it 'does not have duplicate field names' do
      expect(pdf_keys.uniq.size).to eq(pdf_keys.size)
    end
  end
end
