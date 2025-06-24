# frozen_string_literal: true

require 'rails_helper'
require 'pdf_fill/processors/form2210215'
require 'pdf_fill/forms/va2210215'
require 'pdf_fill/forms/va2210215a'

RSpec.describe PdfFill::Processors::Form2210215 do
  let(:claim_id) { 'test_claim_id' }
  let(:fill_options) { {} }
  let(:processor) { described_class.new(form_data, claim_id, fill_options) }

  let(:pdf_files) { [] }
  let(:base_form_data) { get_fixture('pdf_fill/22-10215/simple') }

  before do
    # This is needed because the processor loads form classes from PdfFill::Filler
    %w[
      22-10215
      22-10215a
    ].each do |form_id|
      form_class = "PdfFill::Forms::Va#{form_id.tr('-', '')}".constantize
      PdfFill::Filler.register_form(form_id, form_class)
    end

    # Mocking file system and pdftk calls
    allow(PdfFill::Filler::PDF_FORMS).to receive(:fill_form).and_wrap_original do |_original, *args|
      pdf_files << args[1]
      # original.call(*args) # Don't actually create the file, just track it
    end
    allow(FileUtils).to receive(:cp).and_wrap_original do |_original, *args|
      pdf_files << args[1]
      # original.call(*args)
    end
    allow(PdfFill::Filler::PDF_FORMS).to receive(:cat).and_return(true)
    allow(File).to receive(:delete).and_return(true)
  end

  context 'with an overflow of programs (17 programs)' do
    let(:form_data) do
      base_form_data.merge('programs' => Array.new(17) { { 'name' => 'Program' } })
    end

    it 'generates the main form, intro, and one continuation sheet' do
      processor.process

      expect(pdf_files.count).to eq(3)
      expect(pdf_files[0]).to end_with('22-10215_test_claim_id_main.pdf')
      expect(pdf_files[1]).to end_with('22-10215a-Intro_test_claim_id.pdf')
      expect(pdf_files[2]).to end_with('22-10215a_test_claim_id_page2.pdf')

      expect(PdfFill::Filler::PDF_FORMS).to have_received(:cat).with(
        pdf_files[0], pdf_files[1], pdf_files[2], 'tmp/pdfs/22-10215_test_claim_id.pdf'
      )
    end
  end

  context 'with a large overflow of programs (33 programs)' do
    let(:form_data) do
      base_form_data.merge('programs' => Array.new(33) { { 'name' => 'Program' } })
    end

    it 'generates the main form, intro, and two continuation sheets' do
      processor.process

      expect(pdf_files.count).to eq(4) # main, intro, page2, page3
      expect(pdf_files[0]).to end_with('22-10215_test_claim_id_main.pdf')
      expect(pdf_files[1]).to end_with('22-10215a-Intro_test_claim_id.pdf')
      expect(pdf_files[2]).to end_with('22-10215a_test_claim_id_page2.pdf')
      expect(pdf_files[3]).to end_with('22-10215a_test_claim_id_page3.pdf')

      expect(PdfFill::Filler::PDF_FORMS).to have_received(:cat).with(
        pdf_files[0], pdf_files[1], pdf_files[2], pdf_files[3], 'tmp/pdfs/22-10215_test_claim_id.pdf'
      )
    end
  end
end 