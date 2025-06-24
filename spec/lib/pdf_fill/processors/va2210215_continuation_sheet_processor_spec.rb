# frozen_string_literal: true

require 'rails_helper'
require 'pdf_fill/processors/va2210215_continuation_sheet_processor'
require 'pdf_fill/filler' # The main filler module is the delegate for make_hash_converter

describe PdfFill::Processors::VA2210215ContinuationSheetProcessor do
  # Mock all external dependencies to isolate the processor logic
  let(:pdf_forms_mock) { double('PdfForms') }
  let(:file_utils_mock) { class_double(FileUtils) }
  let(:main_form_filler_mock) { PdfFill::Filler }
  let(:hash_converter_mock) do
    instance_double(PdfFill::HashConverter, transform_data: {}, extras_generator: double(text?: false))
  end

  # Default test data
  let(:file_name_extension) { 'test-claim-id' }
  let(:fill_options) { { created_at: Time.current } }
  let(:programs) { (1..16).map { |i| { 'name' => "Program #{i}" } } }
  let(:form_data) { { 'programs' => programs } }
  let(:final_pdf_path) { "tmp/pdfs/22-10215_#{file_name_extension}.pdf" }
  let(:programs_per_page) { described_class::PROGRAMS_PER_PAGE }

  # The subject of our tests
  let(:processor) do
    described_class.new(form_data, file_name_extension, fill_options, main_form_filler_mock)
  end

  before do
    # Stub constants to inject our mocks
    stub_const('PdfFill::Processors::VA2210215ContinuationSheetProcessor::PDF_FORMS', pdf_forms_mock)
    stub_const('FileUtils', file_utils_mock)

    # Mock file system and PDF toolkit interactions
    allow(file_utils_mock).to receive(:mkdir_p)
    allow(file_utils_mock).to receive(:cp)
    allow(file_utils_mock).to receive(:rm_f)
    allow(pdf_forms_mock).to receive(:fill_form)
    allow(pdf_forms_mock).to receive(:cat)
    allow(main_form_filler_mock).to receive(:make_hash_converter).and_return(hash_converter_mock)

    # Stub form class lookups
    allow(PdfFill::Filler::FORM_CLASSES).to receive(:[]).with('22-10215').and_return(PdfFill::Forms::Va2210215)
    allow(PdfFill::Filler::FORM_CLASSES).to receive(:[]).with('22-10215a').and_return(PdfFill::Forms::Va2210215a)
  end

  describe '#process' do
    subject(:process_call) { processor.process }

    it 'creates the target directory for temporary PDFs' do
      expect(file_utils_mock).to receive(:mkdir_p).with('tmp/pdfs')
      process_call
    end

    it 'returns the path to the final combined PDF' do
      expect(process_call).to eq(final_pdf_path)
    end

    context 'when there are 16 programs (no overflow)' do
      let(:programs) { (1..programs_per_page).map { |i| { 'name' => "Program #{i}" } } }
      let(:main_form_pdf) { "tmp/pdfs/22-10215_#{file_name_extension}_main.pdf" }

      it 'fills only the main form' do
        expect(pdf_forms_mock).to receive(:fill_form).once.with(
          anything, # template path
          main_form_pdf,
          anything, # hash data
          flatten: true
        )
        process_call
      end

      it 'does not copy the continuation intro page' do
        expect(file_utils_mock).not_to receive(:cp)
        process_call
      end

      it 'combines only the main form into the final PDF' do
        expect(pdf_forms_mock).to receive(:cat).with(main_form_pdf, final_pdf_path)
        process_call
      end

      it 'cleans up only the temporary main form PDF' do
        process_call
        expect(file_utils_mock).to have_received(:rm_f).with([main_form_pdf])
      end
    end

    context 'when there are 17 programs (one continuation page)' do
      let(:programs) { (1..(programs_per_page + 1)).map { |i| { 'name' => "Program #{i}" } } }
      let(:main_form_pdf) { "tmp/pdfs/22-10215_#{file_name_extension}_main.pdf" }
      let(:intro_pdf) { "tmp/pdfs/22-10215a-Intro_#{file_name_extension}.pdf" }
      let(:continuation_pdf) { "tmp/pdfs/22-10215a_#{file_name_extension}_page2.pdf" }

      it 'fills the main form with the first 16 programs' do
        expect(pdf_forms_mock).to receive(:fill_form).with(
          'lib/pdf_fill/forms/pdfs/22-10215.pdf',
          main_form_pdf,
          anything,
          flatten: true
        )
        expect_any_instance_of(PdfFill::Forms::Va2210215).to receive(:merge_fields).with(
          hash_including(is_main_form: true)
        ).and_wrap_original do |m, *args|
          expect(args.first[:programs].size).to eq(programs_per_page)
          m.call(*args)
        end

        process_call
      end

      it 'fills one continuation sheet with the remaining program' do
        expect(pdf_forms_mock).to receive(:fill_form).with(
          'lib/pdf_fill/forms/pdfs/22-10215a.pdf',
          continuation_pdf,
          anything,
          flatten: true
        )

        expect_any_instance_of(PdfFill::Forms::Va2210215a).to receive(:merge_fields).with(
          hash_including(page_number: 2, total_pages: 2)
        ).and_wrap_original do |m, *args|
          expect(args.first[:programs].size).to eq(1)
          m.call(*args)
        end
        process_call
      end

      it 'copies the continuation intro page' do
        expect(file_utils_mock).to receive(:cp).with(
          'lib/pdf_fill/forms/pdfs/22-10215a-Intro.pdf',
          intro_pdf
        )
        process_call
      end

      it 'combines the main form, intro, and continuation sheet in order' do
        expect(pdf_forms_mock).to receive(:cat).with(main_form_pdf, intro_pdf, continuation_pdf, final_pdf_path)
        process_call
      end

      it 'cleans up all temporary files' do
        process_call
        expect(file_utils_mock).to have_received(:rm_f).with([main_form_pdf, intro_pdf, continuation_pdf])
      end
    end

    context 'when there are 33 programs (two continuation pages)' do
      let(:programs) { (1..((programs_per_page * 2) + 1)).map { |i| { 'name' => "Program #{i}" } } }
      let(:continuation_pdf_one) { "tmp/pdfs/22-10215a_#{file_name_extension}_page2.pdf" }
      let(:continuation_pdf_two) { "tmp/pdfs/22-10215a_#{file_name_extension}_page3.pdf" }

      it 'fills two continuation sheets' do
        expect(pdf_forms_mock).to receive(:fill_form).with(/22-10215a.*page2/, any_args).once
        expect(pdf_forms_mock).to receive(:fill_form).with(/22-10215a.*page3/, any_args).once
        process_call
      end

      it 'passes the correct programs and page numbers to each sheet' do
        # Sheet 1
        expect_any_instance_of(PdfFill::Forms::Va2210215a).to receive(:merge_fields).with(
          hash_including(page_number: 2, total_pages: 3)
        ).and_wrap_original do |m, *args|
          expect(args.first[:programs].size).to eq(programs_per_page)
          expect(args.first[:programs].first['name']).to eq("Program #{programs_per_page + 1}")
          m.call(*args)
        end
        # Sheet 2
        expect_any_instance_of(PdfFill::Forms::Va2210215a).to receive(:merge_fields).with(
          hash_including(page_number: 3, total_pages: 3)
        ).and_wrap_original do |m, *args|
          expect(args.first[:programs].size).to eq(1)
          expect(args.first[:programs].first['name']).to eq("Program #{(programs_per_page * 2) + 1}")
          m.call(*args)
        end

        process_call
      end
    end

    context 'when an error occurs during PDF combination' do
      let(:programs) { (1..(programs_per_page + 4)).map { |i| { 'name' => "Program #{i}" } } }

      before do
        allow(pdf_forms_mock).to receive(:cat).and_raise(StandardError, 'pdftk failed')
      end

      it 'still cleans up all temporary files' do
        main_form_pdf = "tmp/pdfs/22-10215_#{file_name_extension}_main.pdf"
        intro_pdf = "tmp/pdfs/22-10215a-Intro_#{file_name_extension}.pdf"
        continuation_pdf = "tmp/pdfs/22-10215a_#{file_name_extension}_page2.pdf"

        expect { process_call }.to raise_error(StandardError, 'pdftk failed')

        expect(file_utils_mock).to have_received(:rm_f).with([main_form_pdf, intro_pdf, continuation_pdf])
      end
    end
  end
end
