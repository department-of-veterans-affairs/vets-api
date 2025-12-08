# frozen_string_literal: true

require 'rails_helper'
require 'lib/pdf_fill/fill_form_examples'
require 'employment_questionnaires/pdf_fill/va214140'
require 'fileutils'
require 'tmpdir'
require 'timecop'

describe EmploymentQuestionnaires::PdfFill::Va214140 do
  include SchemaMatchers

  describe '#to_pdf' do
    it 'merges the right keys' do
      f1 = File.read File.join(__dir__, 'test.json')

      claim = EmploymentQuestionnaires::SavedClaim.new(form: JSON.parse(f1).to_s)

      form_id = EmploymentQuestionnaires::FORM_ID
      form_class = EmploymentQuestionnaires::PdfFill::Va214140
      fill_options = {
        created_at: '2025-10-15'
      }
      merged_form_data = form_class.new(claim.parsed_form).merge_fields(fill_options)
      submit_date = Utilities::DateParser.parse(
        fill_options[:created_at]
      )

      hash_converter = PdfFill::Filler.make_hash_converter(form_id, form_class, submit_date, fill_options)
      new_hash = hash_converter.transform_data(form_data: merged_form_data, pdftk_keys: form_class::KEY)

      f2 = File.read File.join(__dir__, 'hashed.json')
      data = JSON.parse(f2)

      expect(new_hash).to eq(data)
    end
  end
end
