# frozen_string_literal: true

require 'rails_helper'
require 'pdf_fill/processors/va220839_processor'
require 'pdf_fill/filler'

describe PdfFill::Processors::VA220839Processor do
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
      let(:saved_claim) { create(:va0839) }

      it 'creates the pdf correctly' do
        processor.process
        expect(File.exist?('tmp/pdfs/22-0839_abc.pdf')).to be(true)
      end

      it 'fills in the form fields' do
        processor.process
        fields = PdfForms.new(Settings.binaries.pdftk).get_fields('tmp/pdfs/22-0839_abc.pdf')
        expect(get_field_value(fields, 'institution_name')).to eq 'Test University'
        expect(get_field_value(fields, 'institution_facility_code')).to eq '12345678'
        expect(get_field_value(fields, 'academic_year')).to eq '2025 to 2025'
        expect(get_field_value(fields, 'poc_name')).to eq 'Jane Doe'
        expect(get_field_value(fields, 'sco_name')).to eq 'Jane Doe2'
      end
    end

    context 'when the officials do overflow' do
      let(:saved_claim) { create(:va0839_overflow) }

      it 'creates the pdf correctly' do
        expect(filler).to receive(:combine_extras).once.and_call_original
        processor.process
        expect(File.exist?('tmp/pdfs/22-0839_abc_final.pdf')).to be(true)
      end

      it 'fills in the form fields' do
        processor.process
        fields = PdfForms.new(Settings.binaries.pdftk).get_fields('tmp/pdfs/22-0839_abc_final.pdf')
        expect(get_field_value(fields, 'institution_name')).to eq 'Test University'
        expect(get_field_value(fields, 'institution_facility_code')).to eq '12345678'
        expect(get_field_value(fields, 'num_eligible_students')).to eq '476'
      end
    end

    context 'with a withdrawal submission' do
      let(:saved_claim) { create(:va0839_withdrawal) }

      it 'creates the pdf correctly' do
        processor.process
        expect(File.exist?('tmp/pdfs/22-0839_abc.pdf')).to be(true)
      end

      it 'fills in the form fields' do
        processor.process
        fields = PdfForms.new(Settings.binaries.pdftk).get_fields('tmp/pdfs/22-0839_abc.pdf')
        expect(get_field_value(fields, 'institution_name')).to eq 'Test University'
        expect(get_field_value(fields, 'institution_facility_code')).to eq '12345678'
        expect(get_field_value(fields, 'branch_campus_0_facility_code')).to eq '87654321'
        expect(get_field_value(fields, 'num_eligible_students')).to eq ''
      end
    end

    context 'with an unlimited max students and/or contribution submission' do
      let(:saved_claim) { create(:va0839_unlimited) }

      it 'creates the pdf correctly' do
        processor.process
        expect(File.exist?('tmp/pdfs/22-0839_abc.pdf')).to be(true)
      end

      it 'fills in the form fields' do
        processor.process
        fields = PdfForms.new(Settings.binaries.pdftk).get_fields('tmp/pdfs/22-0839_abc.pdf')
        expect(get_field_value(fields, 'institution_name')).to eq 'Test University'
        expect(get_field_value(fields, 'institution_facility_code')).to eq '12345678'
        expect(get_field_value(fields, 'num_eligible_students')).to eq 'Varies by degree type'
        expect(get_field_value(fields, 'us_school_0_max_students')).to eq 'Unlimited'
        expect(get_field_value(fields, 'us_school_0_maximum_contribution')).to eq 'Unlimited'
      end
    end
  end
end
