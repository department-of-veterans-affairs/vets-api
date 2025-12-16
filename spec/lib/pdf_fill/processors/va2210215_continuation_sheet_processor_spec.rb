# frozen_string_literal: true

require 'rails_helper'
require 'pdf_fill/processors/va2210215_continuation_sheet_processor'
require 'pdf_fill/filler'

describe PdfFill::Processors::VA2210215ContinuationSheetProcessor do
  let(:pdf_forms_mock) { double('PdfForms') }
  let(:file_utils_mock) { class_double(FileUtils) }
  let(:main_form_filler_mock) { PdfFill::Filler }
  let(:hash_converter_mock) do
    instance_double(PdfFill::HashConverter, transform_data: {}, extras_generator: double(text?: false))
  end

  let(:file_name_extension) { 'test-claim-id' }
  let(:fill_options) { { created_at: Time.current } }
  let(:programs) { (1..16).map { |i| { 'name' => "Program #{i}" } } }
  let(:form_data) { { 'programs' => programs } }
  let(:final_pdf_path) { "tmp/pdfs/22-10215_#{file_name_extension}.pdf" }
  let(:programs_per_page) { described_class::PROGRAMS_PER_PAGE }

  let(:processor) do
    described_class.new(form_data, file_name_extension, fill_options, main_form_filler_mock)
  end

  before do
    stub_const('PdfFill::Processors::VA2210215ContinuationSheetProcessor::PDF_FORMS', pdf_forms_mock)
    stub_const('FileUtils', file_utils_mock)

    allow(file_utils_mock).to receive(:mkdir_p)
    allow(file_utils_mock).to receive(:cp)
    allow(file_utils_mock).to receive(:rm_f)
    allow(pdf_forms_mock).to receive(:fill_form)
    allow(pdf_forms_mock).to receive(:cat)
    allow(main_form_filler_mock).to receive(:make_hash_converter).and_return(hash_converter_mock)

    # Add attr_reader to the form instances for testing purposes
    [PdfFill::Forms::Va2210215, PdfFill::Forms::Va2210215a].each do |form_class|
      allow(form_class).to receive(:new).and_wrap_original do |m, *args|
        instance = m.call(*args)
        instance.class.attr_reader :form_data unless instance.class.method_defined?(:form_data)
        instance
      end
    end

    allow(PdfFill::Filler::FORM_CLASSES).to receive(:[]).with('22-10215').and_return(PdfFill::Forms::Va2210215)
    allow(PdfFill::Filler::FORM_CLASSES).to receive(:[]).with('22-10215a').and_return(PdfFill::Forms::Va2210215a)
  end

  describe '#process' do
    subject(:process_call) { processor.process }

    before do
      # Mock logger to test log_completion
      allow(Rails.logger).to receive(:info)
    end

    it 'creates the target directory for temporary PDFs' do
      expect(file_utils_mock).to receive(:mkdir_p).with('tmp/pdfs')
      process_call
    end

    it 'returns the path to the final combined PDF' do
      expect(process_call).to eq(final_pdf_path)
    end

    it 'calls the logger with completion details' do
      process_call
      expect(Rails.logger).to have_received(:info).with(
        'PdfFill done with continuation sheets',
        hash_including(
          form_id: '22-10215',
          total_pages: 0,
          total_programs: programs_per_page
        )
      )
    end

    context 'when there are 16 programs (no overflow)' do
      let(:programs) { (1..programs_per_page).map { |i| { 'name' => "Program #{i}" } } }
      let(:main_form_pdf) { "tmp/pdfs/22-10215_#{file_name_extension}_main.pdf" }

      it 'fills only the main form' do
        expect(pdf_forms_mock).to receive(:fill_form).once
        process_call
      end

      it 'adds the continuation sheet checkbox marker to the main form data' do
        expect_any_instance_of(PdfFill::Forms::Va2210215).to receive(:merge_fields).and_wrap_original do |m, *_args|
          # We check the data on the instance itself
          expect(m.receiver.form_data['checkbox']).to eq('X')
          m.call
        end
        process_call
      end
    end

    context 'when there are no programs' do
      let(:programs) { [] }
      let(:main_form_pdf) { "tmp/pdfs/22-10215_#{file_name_extension}_main.pdf" }

      it 'generates only the main form and does not create continuation sheets' do
        expect(pdf_forms_mock).to receive(:fill_form).once
        expect(file_utils_mock).not_to receive(:cp)
        expect(pdf_forms_mock).to receive(:cat).with(main_form_pdf, final_pdf_path)
        process_call
      end
    end

    context 'when there are 17 programs (one continuation page)' do
      let(:programs) { (1..(programs_per_page + 1)).map { |i| { 'name' => "Program #{i}" } } }
      let(:main_form_pdf) { "tmp/pdfs/22-10215_#{file_name_extension}_main.pdf" }
      let(:intro_pdf) { "tmp/pdfs/22-10215a-Intro_#{file_name_extension}.pdf" }
      let(:continuation_pdf) { "tmp/pdfs/22-10215a_#{file_name_extension}_page1.pdf" }

      it 'fills the main form and one continuation sheet' do
        allow(pdf_forms_mock).to receive(:fill_form)
        process_call
        expect(pdf_forms_mock).to have_received(:fill_form).twice
      end

      it 'calculates total_pages correctly' do
        expect_any_instance_of(PdfFill::Forms::Va2210215a).to receive(:merge_fields).with(
          hash_including(page_number: 1, total_pages: 1)
        ).and_call_original
        process_call
      end
    end
  end

  describe '#initialize' do
    it 'sorts programs by programName alphabetically' do
      unsorted_programs = [
        { 'programName' => 'Zebra Program', 'studentsEnrolled' => 100 },
        { 'programName' => 'Apple Program', 'studentsEnrolled' => 50 },
        { 'programName' => 'Banana Program', 'studentsEnrolled' => 75 }
      ]
      form_data['programs'] = unsorted_programs
      processor = described_class.new(form_data, file_name_extension, fill_options, main_form_filler_mock)

      sorted_names = processor.instance_variable_get(:@programs).map { |p| p['programName'] }
      expect(sorted_names).to eq(['Apple Program', 'Banana Program', 'Zebra Program'])
    end

    it 'updates form_data with sorted programs' do
      unsorted_programs = [
        { 'programName' => 'Zebra Program', 'studentsEnrolled' => 100 },
        { 'programName' => 'Apple Program', 'studentsEnrolled' => 50 }
      ]
      form_data['programs'] = unsorted_programs
      described_class.new(form_data, file_name_extension, fill_options, main_form_filler_mock)

      sorted_names = form_data['programs'].map { |p| p['programName'] }
      expect(sorted_names).to eq(['Apple Program', 'Zebra Program'])
    end

    it 'handles nil programs gracefully' do
      form_data['programs'] = nil
      expect do
        processor = described_class.new(form_data, file_name_extension, fill_options, main_form_filler_mock)
        expect(processor.instance_variable_get(:@programs)).to eq([])
      end.not_to raise_error
    end

    it 'handles empty programs array gracefully' do
      form_data['programs'] = []
      processor = described_class.new(form_data, file_name_extension, fill_options, main_form_filler_mock)
      expect(processor.instance_variable_get(:@programs)).to eq([])
    end
  end
end
