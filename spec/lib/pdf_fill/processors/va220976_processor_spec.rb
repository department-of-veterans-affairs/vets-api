# frozen_string_literal: true

require 'rails_helper'
require 'pdf_fill/processors/va220976_processor'
require 'pdf_fill/filler'

describe PdfFill::Processors::VA220976Processor do
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
    context 'when the content does not overflow' do
      let(:saved_claim) { create(:va0976) }

      it 'creates the pdf correctly' do
        processor.process
        expect(File.exist?('tmp/pdfs/22-0976_abc.pdf')).to be(true)
      end

      it 'fills in the form fields' do
        processor.process
        fields = PdfForms.new(Settings.binaries.pdftk).get_fields('tmp/pdfs/22-0976_abc.pdf')
        expect(get_field_value(fields, 'submission_type_initial')).to eq 'Yes'
        expect(get_field_value(fields, 'institution_name')).to eq 'Test University'
        expect(get_field_value(fields, 'institution_facility_code')).to eq '12345678'
        expect(get_field_value(fields, 'degree_program_0_name')).to eq 'Physics'
        expect(get_field_value(fields, 'authorizing_initials_1')).to eq 'JH'
        expect(get_field_value(fields, 'faculty_0_name')).to eq 'John A Doe'
        expect(get_field_value(fields, 'sco_name')).to eq 'John A Doe'
        expect(get_field_value(fields, 'authorizing_official_signature')).to eq 'John Doe'
      end
    end

    context 'when the content does overflow' do
      let(:saved_claim) { create(:va0976_overflow) }

      it 'creates the pdf correctly' do
        processor.process
        expect(File.exist?('tmp/pdfs/22-0976_abc_final.pdf')).to be(true)
      end

      it 'fills in the form fields' do
        processor.process
        fields = PdfForms.new(Settings.binaries.pdftk).get_fields('tmp/pdfs/22-0976_abc_final.pdf')
        expect(get_field_value(fields, 'submission_type_initial')).to eq 'Yes'
        expect(get_field_value(fields, 'institution_name')).to eq 'Test University'
        expect(get_field_value(fields, 'institution_facility_code')).to eq '12345678'
        expect(get_field_value(fields, 'degree_program_0_name')).to eq 'Physics'
        expect(get_field_value(fields, 'authorizing_initials_1')).to eq 'JH'
        expect(get_field_value(fields, 'faculty_0_name')).to eq 'John A Doe'
        expect(get_field_value(fields, 'sco_name')).to eq 'John A Doe'
        expect(get_field_value(fields, 'authorizing_official_signature')).to eq 'John Doe'

        expect(get_field_value(fields, 'degree_program_3_name')).to eq 'Politics'
        expect(get_field_value(fields, 'branch_3_name')).to eq 'Branch 4'
        expect(get_field_value(fields, 'faculty_6_name')).to eq 'John A Doe6'
      end
    end
  end
end
