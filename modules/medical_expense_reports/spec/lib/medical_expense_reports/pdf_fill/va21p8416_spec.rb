# frozen_string_literal: true

require 'rails_helper'
require 'lib/pdf_fill/fill_form_examples'
require 'medical_expense_reports/pdf_fill/va21p8416'
require 'pdf_utilities/datestamp_pdf'
require 'fileutils'
require 'tmpdir'
require 'timecop'

describe MedicalExpenseReports::PdfFill::Va21p8416 do
  include SchemaMatchers

  describe '#to_pdf' do
    it 'merges the right keys' do
      Timecop.freeze(Time.zone.parse('2025-10-21')) do
        files = %w[diffs kitchen-sink_us-number]
        files.map do |file|
          f1 = File.read File.join(__dir__, 'input', "21p-8416_#{file}.json")

          claim = MedicalExpenseReports::SavedClaim.new(form: f1)

          form_id = MedicalExpenseReports::FORM_ID
          form_class = MedicalExpenseReports::PdfFill::Va21p8416
          fill_options = {
            created_at: '2025-10-08'
          }
          merged_form_data = form_class.new(claim.parsed_form).merge_fields(fill_options)
          submit_date = Utilities::DateParser.parse(
            fill_options[:created_at]
          )

          hash_converter = PdfFill::Filler.make_hash_converter(form_id, form_class, submit_date, fill_options)
          new_hash = hash_converter.transform_data(form_data: merged_form_data, pdftk_keys: form_class::KEY)

          f2 = File.read File.join(__dir__, 'output', "21p-8416_#{file}.json")
          data = JSON.parse(f2)

          expect(new_hash).to eq(data)
        end
      end
    end
  end

  describe '.stamp_signature' do
    let(:pdf_path) { '/tmp/test_form.pdf' }
    let(:stamped_path) { '/tmp/test_form_stamped.pdf' }
    let(:datestamp_instance) { instance_double(PDFUtilities::DatestampPdf) }
    let(:coordinates) { { x: 123, y: 456, page_number: 7 } }

    before do
      allow(PDFUtilities::DatestampPdf).to receive(:new).with(pdf_path).and_return(datestamp_instance)
      allow(described_class).to receive(:signature_overlay_coordinates).and_return(coordinates)
    end

    it 'stamps the signature when present' do
      expect(datestamp_instance).to receive(:run).with(
        text: 'Jane Doe',
        x: coordinates[:x],
        y: coordinates[:y],
        page_number: coordinates[:page_number],
        size: described_class::SIGNATURE_FONT_SIZE,
        text_only: true,
        timestamp: '',
        template: pdf_path,
        multistamp: true
      ).and_return(stamped_path)

      result = described_class.stamp_signature(pdf_path, { 'statementOfTruthSignature' => 'Jane Doe' })
      expect(result).to eq(stamped_path)
    end

    it 'returns the original PDF when signature is blank' do
      result = described_class.stamp_signature(pdf_path, { 'statementOfTruthSignature' => '' })
      expect(result).to eq(pdf_path)
      expect(PDFUtilities::DatestampPdf).not_to have_received(:new)
    end

    it 'rescues errors and returns the original PDF path' do
      allow(datestamp_instance).to receive(:run).and_raise(StandardError, 'boom')

      result = described_class.stamp_signature(pdf_path, { 'statementOfTruthSignature' => 'Jane Doe' })
      expect(result).to eq(pdf_path)
    end
  end
end
