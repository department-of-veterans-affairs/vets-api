# frozen_string_literal: true

require 'rails_helper'
require 'lib/pdf_fill/fill_form_examples'
require 'survivors_benefits/pdf_fill/va21p534ez'
require 'fileutils'
require 'tmpdir'
require 'timecop'

describe SurvivorsBenefits::PdfFill::Va21p534ez do
  include SchemaMatchers

  describe '#to_pdf' do
    it 'merges the right keys' do
      Timecop.freeze(Time.zone.parse('2025-10-27')) do
        files = %w[
          empty
          section-1 section-1_2
          section-2 section-2_1 section-2_2 section-2_3
          section-3 section-3_1 section-3_2 section-3_3 section-3_4 section-3_5 section-3_6 section-3_7
          section-4 section-4_1 section-4_2 section-4_3
          section-5 section-5_1 section-5_2
          section-6 section-6_1
          section-7 section-7_1 section-7_2
          section-8 section-8_1
          section-9 section-9_1 section-9_2 section-9_3 section-9_4
          section-10 section-10_1 section-10_2
          section-11 section-11_1 section-11_2
        ]
        files.map do |file|
          f1 = File.read File.join(__dir__, 'input', "21P-534EZ_#{file}.json")

          claim = SurvivorsBenefits::SavedClaim.new(form: f1)

          form_id = SurvivorsBenefits::FORM_ID
          form_class = SurvivorsBenefits::PdfFill::Va21p534ez
          fill_options = {
            created_at: '2025-10-08'
          }
          merged_form_data = form_class.new(claim.parsed_form).merge_fields(fill_options)
          submit_date = Utilities::DateParser.parse(
            fill_options[:created_at]
          )

          hash_converter = PdfFill::Filler.make_hash_converter(form_id, form_class, submit_date, fill_options)
          new_hash = hash_converter.transform_data(form_data: merged_form_data, pdftk_keys: form_class::KEY)

          f2 = File.read File.join(__dir__, 'output', "21P-534EZ_#{file}.json")
          data = JSON.parse(f2)

          filtered = new_hash.slice(*(new_hash.keys & data.keys))

          expect(filtered).to eq(data)
        end
      end
    end
  end
end
