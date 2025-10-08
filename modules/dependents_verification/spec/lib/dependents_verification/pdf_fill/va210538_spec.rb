# frozen_string_literal: true

require 'rails_helper'
require 'dependents_verification/pdf_fill/va210538'
require 'lib/pdf_fill/fill_form_examples'

def basic_class
  DependentsVerification::PdfFill::Va210538.new({})
end

describe DependentsVerification::PdfFill::Va210538 do
  let(:form_data) do
    JSON.parse(File.read("#{DependentsVerification::MODULE_PATH}/spec/fixtures/pdf_fill/#{DependentsVerification::FORM_ID}/kitchen_sink.json"))
  end

  let(:path) { 'modules/dependents_verification/lib/dependents_verification/pdf_fill/pdfs/21-0538.pdf' }
  let :keys do
    def get_keys(hash)
      hash.map do |key, value|
        if key == :key
          value
        elsif value.key?(:key)
          value[:key] unless value[:overflow_only]
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

  it_behaves_like 'a form filler', {
    form_id: described_class::FORM_ID,
    factory: :dependents_verification_claim,
    test_data_types: %w[kitchen_sink],
    input_data_fixture_dir: "#{DependentsVerification::MODULE_PATH}/spec/fixtures/pdf_fill/#{DependentsVerification::FORM_ID}",
    output_pdf_fixture_dir: "#{DependentsVerification::MODULE_PATH}/spec/fixtures/pdf_fill/#{DependentsVerification::FORM_ID}",
    # Override the time for shared examples to ensure consistent timestamps from fixtures
    run_at: '2025-06-25 00:00:00 UTC'
  }

  describe '#merge_fields' do
    it 'merges the right fields', run_at: '2025-06-25 00:00:00 UTC' do
      expect(described_class.new(form_data).merge_fields.to_json).to eq(
        get_fixture_absolute("#{DependentsVerification::MODULE_PATH}/spec/fixtures/pdf_fill/#{DependentsVerification::FORM_ID}/merge_fields").to_json
      )
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
