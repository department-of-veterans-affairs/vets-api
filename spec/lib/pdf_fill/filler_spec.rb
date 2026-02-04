# frozen_string_literal: true

require 'rails_helper'
require 'pdf_fill/filler'
require 'lib/pdf_fill/fill_form_examples'

# This whole suite is approx 57 tests as of this review. It looks deceptively smaller
# than it is.
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

  # there are approx. 46 tests here which is deceptive.
  describe '#fill_ancillary_form', run_at: '2017-07-25 00:00:00 -0400' do
    def overflow_file_suffix(extras_redesign, show_jumplinks)
      return '_extras.pdf' unless extras_redesign

      show_jumplinks ? '_redesign_extras_jumplinks.pdf' : '_redesign_extras.pdf'
    end

    %w[21-4142 21-0781a 21-0781 21-0781V2 21-8940 28-8832 28-1900 21-674 21-674-V2 26-1880 5655
       22-10216 22-10215 22-10215a 22-1919 22-10275 22-10272].each do |form_id|
      context "form #{form_id}" do
        form_types = %w[simple kitchen_sink overflow].map { |type| [type, false, false] }
        form_types.push(['overflow', true, false], ['overflow', true, true]) if form_id == '21-0781V2'
        form_types.each do |type, extras_redesign, show_jumplinks|
          context "with type=#{type} extras_redesign=#{extras_redesign} show_jumplinks=#{show_jumplinks}" do
            let(:form_data) do
              get_fixture("pdf_fill/#{form_id}/#{type}")
            end

            it 'fills the form correctly' do
              if type == 'overflow'
                the_extras_generator = nil
                expect(described_class).to receive(:combine_extras).once do |old_file_path, extras_generator|
                  the_extras_generator = extras_generator
                  old_file_path
                end
              end

              # this is only for 21-674-V2 but it passes in the extras hash. passing nil for all other scenarios
              student = form_id == '21-674-V2' ? form_data['dependents_application']['student_information'][0] : nil

              expect(described_class).to receive(:stamp_form).once.and_call_original if extras_redesign

              file_path = described_class.fill_ancillary_form(form_data, 1, form_id,
                                                              { extras_redesign:, student:, show_jumplinks: })

              fixture_pdf_base = "spec/fixtures/pdf_fill/#{form_id}/#{type}"

              if type == 'overflow'
                extras_path = the_extras_generator.generate
                fixture_pdf = fixture_pdf_base + overflow_file_suffix(extras_redesign, show_jumplinks)
                expect(extras_path).to match_file_exactly(fixture_pdf)

                File.delete(extras_path)
              end

              fixture_pdf = fixture_pdf_base + (extras_redesign ? '_redesign.pdf' : '.pdf')
              expect(file_path).to match_pdf_fields(fixture_pdf)

              File.delete(file_path)
            end
          end
        end
      end
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
end
