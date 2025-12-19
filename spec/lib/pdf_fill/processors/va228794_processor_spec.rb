# frozen_string_literal: true

require 'rails_helper'
require 'pdf_fill/processors/va228794_processor'
require 'pdf_fill/filler'

describe PdfFill::Processors::VA228794Processor do
  let(:form_data) { saved_claim.parsed_form }
  let(:filler) { PdfFill::Filler }
  let(:processor) { described_class.new(form_data, filler, 'abc') }

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
        processor.process
        expect(File.exist?('tmp/pdfs/22-8794_abc.pdf')).to be(true)
      end

      it 'fills in the form fields' do
        sub_str = 'Online submission - no signature required'

        processor.process
        fields = PdfForms.new(Settings.binaries.pdftk).get_fields('tmp/pdfs/22-8794_abc.pdf')
        expect(get_field_value(fields, 'institution_facility_code')).to eq '12345678'
        expect(get_field_value(fields, 'signature_email')).to eq 'john.doe@example.com'
        expect(get_field_value(fields, 'signature_name')).to eq 'John A Doe, Designating Official'
        expect(get_field_value(fields, 'additional_certifying_officials_0_phone')).to eq '5556071235'
        expect(get_field_value(fields,
                               'additional_certifying_officials_0_signature')).to eq sub_str
        expect(get_field_value(fields, 'additional_certifying_officials_1_phone')).to eq '3334445555'
        expect(get_field_value(fields, 'signature_phone')).to eq '5556071234'
      end
    end

    context 'when the officials do overflow' do
      let(:saved_claim) { create(:va8794_overflow) }

      it 'creates the pdf correctly' do
        expect(filler).to receive(:combine_extras).once.and_call_original
        processor.process
        expect(File.exist?('tmp/pdfs/22-8794_abc_final.pdf')).to be(true)
      end

      it 'fills in the form fields' do
        processor.process
        fields = PdfForms.new(Settings.binaries.pdftk).get_fields('tmp/pdfs/22-8794_abc_final.pdf')
        expect(get_field_value(fields, 'institution_facility_code')).to eq '12345678'
        expect(get_field_value(fields, 'signature_email')).to eq 'john.doe@example.com'
        expect(get_field_value(fields, 'additional_certifying_officials_6_email')).to eq 'john_official6@example.com'
        expect(get_field_value(fields, 'remarks')).to eq 'See attached page'
      end
    end
  end
end
