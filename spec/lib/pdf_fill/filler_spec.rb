# frozen_string_literal: true

require 'rails_helper'
require 'pdf_fill/filler'
require 'lib/pdf_fill/fill_form_examples'

# Unit tests and fill_form integration tests for PdfFill::Filler.
# Ancillary form fill tests are split into separate files for CI parallelization:
#   - filler_ancillary_forms_1_spec.rb (heavy forms: 22-10215, 21-674, 21-0781V2, etc.)
#   - filler_ancillary_forms_2_spec.rb (lighter forms: 21-4142, 28-1900, 5655, etc.)
describe PdfFill::Filler, type: :model do
  include SchemaMatchers

  describe '#combine_extras' do
    subject do
      described_class.combine_extras(old_file_path, extras_generator, form_class)
    end

    let(:extras_generator) { double }
    let(:old_file_path) { 'tmp/pdfs/file_path.pdf' }
    let(:form_class) { PdfFill::Forms::Va210781v2 }

    context 'when extras_generator doesnt have text' do
      it 'returns the old_file_path' do
        expect(extras_generator).to receive(:text?).once.and_return(false)

        expect(subject).to eq(old_file_path)
      end
    end

    context 'when extras_generator has text' do
      before do
        expect(extras_generator).to receive(:text?).once.and_return(true)
      end

      it 'generates extras and combine the files' do
        file_path = 'tmp/pdfs/file_path_final.pdf'
        expect(extras_generator).to receive(:generate).once.and_return('extras.pdf')
        expect(described_class).to receive(:merge_pdfs).once.with(old_file_path, 'extras.pdf', file_path)
        expect(File).to receive(:delete).once.with('extras.pdf')
        expect(File).to receive(:delete).once.with(old_file_path)

        expect(subject).to eq(file_path)
      end
    end
  end

  # NOTE: 21P-0969 is one of the only forms that uses data types that are supported by HexaPDF currently
  describe '#fill_form_with_hexapdf' do
    it_behaves_like 'a form filler', {
      form_id: IncomeAndAssets::FORM_ID,
      factory: :income_and_assets_claim,
      use_vets_json_schema: true,
      input_data_fixture_dir: "modules/income_and_assets/spec/fixtures/pdf_fill/#{IncomeAndAssets::FORM_ID}",
      output_pdf_fixture_dir: "modules/income_and_assets/spec/fixtures/pdf_fill/#{IncomeAndAssets::FORM_ID}",
      fill_options: { extras_redesign: true, omit_esign_stamp: true, use_hexapdf: true }
    }
  end

  # see `fill_form_examples.rb` for documentation about options
  describe '#fill_form' do
    [
      { form_id: '686C-674', factory: :dependency_claim },
      { form_id: '686C-674-V2', factory: :dependency_claim_v2 }
    ].each do |options|
      it_behaves_like 'a form filler', options
    end
  end

  describe '#fill_ancillary_form with form_id is 21-0781V2' do
    context 'when form_id is 21-0781V2' do
      let(:form_id) { '21-0781V2' }
      let(:form_data) do
        get_fixture('pdf_fill/21-0781V2/kitchen_sink')
      end
      let(:hash_converter) { PdfFill::HashConverter.new('%m/%d/%Y', extras_generator) }
      let(:extras_generator) { instance_double(PdfFill::ExtrasGenerator) }
      let(:merged_form_data) do
        PdfFill::Forms::Va210781v2.new(form_data).merge_fields('signatureDate' => Time.now.utc.to_s)
      end
      let(:new_hash) do
        hash_converter.transform_data(form_data: merged_form_data, pdftk_keys: PdfFill::Forms::Va210781v2::KEY)
      end
      let(:template_path) { 'lib/pdf_fill/forms/pdfs/21-0781V2.pdf' }
      let(:file_path) { 'tmp/pdfs/21-0781V2_12346.pdf' }
      let(:claim_id) { '12346' }

      it 'uses UNICODE_PDF_FORMS to fill the form for form_id 21-0781V2' do
        # Mock the hash converter and its behavior
        allow(extras_generator).to receive(:text?).once.and_return(true)
        allow(extras_generator).to receive(:use_hexapdf).and_return(false)
        allow(extras_generator).to receive(:add_text)
        allow(hash_converter).to receive(:transform_data).and_return(new_hash)

        # Mock UNICODE_PDF_FORMS and PDF_FORMS
        allow(described_class::UNICODE_PDF_FORMS).to receive(:fill_form).and_call_original
        allow(described_class::PDF_FORMS).to receive(:fill_form).and_call_original

        generated_pdf_path = described_class.fill_ancillary_form(form_data, claim_id, form_id)
        unicode_text = 'Lorem ‒–—―‖‗‘’‚‛“”„‟′″‴á, é, í, ó, ú, Á, É, Í, Ó, Úñ, Ñ¿, ¡ipsum dolor sit amet'
        expect(File).to exist(generated_pdf_path)
        expect(described_class::UNICODE_PDF_FORMS).to have_received(:fill_form).with(
          template_path, generated_pdf_path, hash_including('F[0].#subform[5].Remarks_If_Any[0]' => unicode_text),
          flatten: false
        )

        expect(described_class::PDF_FORMS).not_to have_received(:fill_form)

        File.delete(file_path)
      end
    end
  end

  describe '#should_stamp_form?' do
    subject { described_class.should_stamp_form?(form_id, fill_options, submit_date) }

    let(:form_id) { '21-0781V2' }
    let(:fill_options) { { extras_redesign: true } }
    let(:submit_date) { DateTime.new(2020, 12, 25, 14, 30, 0, '+0000') }

    context 'when not given the extras_redesign fill option' do
      let(:fill_options) { {} }

      it { is_expected.to be(false) }

      context 'when filling out a non-redesigned dependent form' do
        let(:form_id) { '686C-674' }

        it { is_expected.to be(true) }
      end
    end

    context 'when given the omit_esign_stamp fill option' do
      let(:fill_options) { { omit_esign_stamp: true, extras_redesign: true } }

      it { is_expected.to be(false) }
    end
  end

  describe '#stamp_form' do
    subject { described_class.stamp_form(file_path, submit_date) }

    let(:file_path) { 'tmp/test.pdf' }
    let(:submit_date) { DateTime.new(2020, 12, 25, 14, 30, 0, '+0000') }
    let(:datestamp_pdf) { instance_double(PDFUtilities::DatestampPdf) }
    let(:stamped_path) { 'tmp/test_stamped.pdf' }
    let(:final_path) { 'tmp/test_final.pdf' }

    before do
      allow(PDFUtilities::DatestampPdf).to receive(:new).and_return(datestamp_pdf)
      allow(datestamp_pdf).to receive(:run).and_return(stamped_path, final_path)
    end

    it 'stamps the form with footer and header' do
      expected_footer = 'Signed electronically and submitted via VA.gov at 14:30 UTC 2020-12-25. ' \
                        'Signee signed with an identity-verified account.'

      expect(PDFUtilities::DatestampPdf).to receive(:new).with(file_path).ordered
      expect(datestamp_pdf).to receive(:run).with(
        text: expected_footer,
        x: 5,
        y: 5,
        text_only: true,
        size: 9
      ).ordered.and_return(stamped_path)

      expect(PDFUtilities::DatestampPdf).to receive(:new).with(stamped_path).ordered
      expect(datestamp_pdf).to receive(:run).with(
        text: 'VA.gov Submission',
        x: 510,
        y: 775,
        text_only: true,
        size: 9
      ).ordered.and_return(final_path)

      expect(File).to receive(:delete).with(stamped_path)

      expect(subject).to eq(final_path)
    end

    context 'when an error occurs' do
      before do
        allow(datestamp_pdf).to receive(:run).and_raise(StandardError, 'PDF Error')
        allow(Rails.logger).to receive(:error)
      end

      it 'logs the error and returns the original file path' do
        expect(subject).to eq(file_path)
        expect(Rails.logger).to have_received(:error).with(
          "Error stamping form for PdfFill: #{file_path}, error: PDF Error"
        )
      end
    end
  end

  describe '#validate_field_names' do
    let(:form_id) { '28-1900' }
    let(:template_path) { 'lib/pdf_fill/forms/pdfs/28-1900.pdf' }
    let(:template_fields) { %w[field1 field2 field3] }

    before do
      allow(described_class).to receive(:extract_template_field_names).with(template_path).and_return(template_fields)
    end

    context 'when all field names match the template' do
      let(:data_hash) { { 'field1' => 'value1', 'field2' => 'value2', 'field3' => 'value3' } }

      it 'does not increment any StatsD metrics' do
        expect(StatsD).not_to receive(:increment)

        described_class.validate_field_names(template_path, data_hash, form_id)
      end
    end

    context 'when some field names do not match the template' do
      let(:data_hash) { { 'field1' => 'value1', 'wrong_field' => 'value2', 'another_wrong' => 'value3' } }

      it 'increments StatsD mismatch metric' do
        expect(StatsD).to receive(:increment).with('api.pdf_fill.field_validation.mismatch',
                                                   tags: ["form_id:#{form_id}"])

        described_class.validate_field_names(template_path, data_hash, form_id)
      end
    end

    context 'when template fields cannot be extracted' do
      let(:data_hash) { { 'field1' => 'value1' } }

      before do
        allow(described_class).to receive(:extract_template_field_names).with(template_path).and_return([])
      end

      it 'increments StatsD mismatch metric' do
        expect(StatsD).to receive(:increment).with('api.pdf_fill.field_validation.mismatch',
                                                   tags: ["form_id:#{form_id}"])

        described_class.validate_field_names(template_path, data_hash, form_id)
      end
    end
  end

  describe '#extract_template_field_names' do
    let(:template_path) { 'lib/pdf_fill/forms/pdfs/28-1900.pdf' }
    let(:field_names) do
      [
        'form1[0].#subform[0].FirstName[0]',
        'form1[0].#subform[0].LastName[0]'
      ]
    end

    context 'when pdftk successfully extracts fields' do
      before do
        allow(PdfFill::Filler::PDF_FORMS).to receive(:get_field_names)
          .with(template_path)
          .and_return(field_names)
      end

      it 'returns array of field names' do
        result = described_class.extract_template_field_names(template_path)

        expect(result).to eq(field_names)
      end
    end

    context 'when pdftk command fails' do
      before do
        allow(PdfFill::Filler::PDF_FORMS).to receive(:get_field_names)
          .with(template_path)
          .and_raise(StandardError.new('Error: file not found'))
      end

      it 'returns empty array' do
        result = described_class.extract_template_field_names(template_path)

        expect(result).to eq([])
      end

      it 'logs warning message' do
        expect(Rails.logger).to receive(:warn).with(
          'Failed to extract fields from PDF template',
          template_path:,
          error: 'Error: file not found'
        )

        described_class.extract_template_field_names(template_path)
      end
    end
  end
end
