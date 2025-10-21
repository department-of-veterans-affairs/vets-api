# frozen_string_literal: true

require 'rails_helper'
require 'lib/pdf_fill/fill_form_examples'
require 'medical_expense_reports/pdf_fill/va21p8416'
require 'fileutils'
require 'tmpdir'
require 'timecop'

describe MedicalExpenseReports::PdfFill::Va21p8416 do
  include SchemaMatchers

  describe '#to_pdf' do
    it 'merges the right keys' do
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
