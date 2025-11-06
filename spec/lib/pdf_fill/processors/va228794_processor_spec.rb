# frozen_string_literal: true

require 'rails_helper'
require 'pdf_fill/processors/va228794_processor'
require 'pdf_fill/filler'

describe PdfFill::Processors::VA228794Processor do
  let(:form_data) { saved_claim.parsed_form }
  let(:filler) { PdfFill::Filler }

  before do
    allow(Flipper).to receive(:enabled?).with(:saved_claim_pdf_overflow_tracking).and_return(false)
  end

  after do
    FileUtils.rm_rf('tmp/pdfs')
  end

  def get_field_value(fields, name)
    fields.find { |f| f.name == name }&.value
  end

  describe '#process' do
    context 'when the officials do no overflow' do
      let(:saved_claim) { create(:va8794) }

      it 'creates the pdf correctly' do
        described_class.new(form_data, filler).process
        expect(File.exist?('tmp/pdfs/22-8794.pdf')).to be(true)
      end

      it 'fills in the form fields' do
        described_class.new(form_data, filler).process
        fields = PdfForms.new(Settings.binaries.pdftk).get_fields('tmp/pdfs/22-8794.pdf')
        expect(get_field_value(fields, 'institution_facility_code')).to eq '12345678'
        expect(get_field_value(fields, 'signature_email')).to eq 'john.doe@example.com'
      end
    end

    context 'when the officials do overflow' do
      let(:saved_claim) { create(:va8794_overflow) }

      it 'creates the pdf correctly' do
        expect(filler).to receive(:combine_extras).once.and_call_original
        described_class.new(form_data, filler).process
        expect(File.exist?('tmp/pdfs/22-8794_final.pdf')).to be(true)
      end

      it 'fills in the form fields' do
        described_class.new(form_data, filler).process
        fields = PdfForms.new(Settings.binaries.pdftk).get_fields('tmp/pdfs/22-8794_final.pdf')
        expect(get_field_value(fields, 'institution_facility_code')).to eq '12345678'
        expect(get_field_value(fields, 'signature_email')).to eq 'john.doe@example.com'
        expect(get_field_value(fields, 'additional_certifying_officials_6_email')).to eq 'john_official6@example.com'
      end
    end
  end
end
