# frozen_string_literal: true

require 'rails_helper'
require 'pdf_fill/processors/va2210215_continuation_sheet_processor'
require 'pdf_fill/filler'

describe PdfFill::Processors::VA2210215ContinuationSheetProcessor do
  let(:form_data) do
    { 'programs' => (1..20).map { |i| { 'name' => "Program #{i}" } } }
  end
  let(:file_name_extension) { 'test_claim' }
  let(:fill_options) { {} }
  let(:main_form_filler) { PdfFill::Filler }

  let(:processor) do
    described_class.new(form_data, file_name_extension, fill_options, main_form_filler)
  end

  let(:pdf_forms_mock) { instance_double(PdfForms) }
  let(:file_utils_mock) { class_double(FileUtils) }
  let(:file_mock) { class_double(File) }

  before do
    stub_const('PdfFill::Processors::VA2210215ContinuationSheetProcessor::PDF_FORMS', pdf_forms_mock)
    stub_const('FileUtils', file_utils_mock)
    stub_const('File', file_mock)

    allow(pdf_forms_mock).to receive(:fill_form)
    allow(pdf_forms_mock).to receive(:cat)
    allow(file_utils_mock).to receive(:mkdir_p)
    allow(file_utils_mock).to receive(:cp)
    allow(file_mock).to receive(:exist?).and_return(true)
    allow(file_mock).to receive(:delete)

    # Stubbing hash converter logic
    hash_converter_mock = double
    allow(hash_converter_mock).to receive(:transform_data).and_return({})
    allow(main_form_filler).to receive(:make_hash_converter).and_return(hash_converter_mock)
  end

  describe '#process' do
    it 'creates the pdfs directory' do
      expect(file_utils_mock).to receive(:mkdir_p).with('tmp/pdfs')
      processor.process
    end

    context 'with more than 16 programs' do
      let(:form_data) { { 'programs' => (1..17).map { |i| { 'name' => "Program #{i}" } } } }

      it 'generates a main form, an intro page, and one continuation sheet' do
        expect(pdf_forms_mock).to receive(:fill_form).exactly(2).times
        expect(file_utils_mock).to receive(:cp).once
        processor.process
      end

      it 'combines three PDF files' do
        expect(pdf_forms_mock).to receive(:cat) do |*args|
          expect(args.size).to eq(4) # 3 input files + 1 output file
        end
        processor.process
      end
    end

    context 'with 33 programs' do
      let(:form_data) { { 'programs' => (1..33).map { |i| { 'name' => "Program #{i}" } } } }

      it 'generates a main form, an intro page, and two continuation sheets' do
        expect(pdf_forms_mock).to receive(:fill_form).exactly(3).times
        expect(file_utils_mock).to receive(:cp).once
        processor.process
      end

      it 'combines four PDF files' do
        expect(pdf_forms_mock).to receive(:cat) do |*args|
          expect(args.size).to eq(5)
        end
        processor.process
      end
    end

    it 'cleans up temporary files' do
      allow(pdf_forms_mock).to receive(:cat)
      processor.process
      expect(file_mock).to have_received(:delete).at_least(:once)
    end

    it 'does not attempt to delete non-existent files' do
      allow(file_mock).to receive(:exist?).and_return(false)
      expect(file_mock).not_to receive(:delete)
      processor.process
    end

    it 'returns the path to the final combined PDF' do
      final_path = "tmp/pdfs/22-10215_#{file_name_extension}.pdf"
      allow(pdf_forms_mock).to receive(:cat).and_return(final_path)
      expect(processor.process).to eq(final_path)
    end

    it 'calls PDF_FORMS.cat with the correct files in order' do
      main_form_path = "tmp/pdfs/22-10215_#{file_name_extension}_main.pdf"
      intro_path = "tmp/pdfs/22-10215a-Intro_#{file_name_extension}.pdf"
      continuation_path = "tmp/pdfs/22-10215a_#{file_name_extension}_page2.pdf"
      final_path = "tmp/pdfs/22-10215_#{file_name_extension}.pdf"

      expect(pdf_forms_mock).to receive(:cat).with(
        main_form_path,
        intro_path,
        continuation_path,
        final_path
      )

      processor.process
    end
  end
end 