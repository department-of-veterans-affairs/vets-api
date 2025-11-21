# frozen_string_literal: true

require 'rails_helper'

def basic_class
  IncreaseCompensation::PdfFill::Va218940v1.new({})
end

describe IncreaseCompensation::PdfFill::Va218940v1 do
  include SchemaMatchers

  describe '#to_pdf' do
    it 'merges the right keys' do
      f1 = File.read File.join(__dir__, '21-8940_kitchen-sink.json')

      claim = IncreaseCompensation::SavedClaim.new(form: JSON.parse(f1).to_s)

      form_id = IncreaseCompensation::FORM_ID
      form_class = IncreaseCompensation::PdfFill::Va218940v1
      fill_options = {
        created_at: '2025-10-15'
      }
      merged_form_data = form_class.new(claim.parsed_form).merge_fields(fill_options)
      submit_date = Utilities::DateParser.parse(
        fill_options[:created_at]
      )

      hash_converter = PdfFill::Filler.make_hash_converter(form_id, form_class, submit_date, fill_options)
      new_hash = hash_converter.transform_data(form_data: merged_form_data, pdftk_keys: form_class::KEY)

      f2 = File.read File.join(__dir__, '21-8940_hashed.json')
      data = JSON.parse(f2)

      expect(new_hash).to eq(data)
    end
  end

  def normalize_values(obj)
    case obj
    when Array
      obj.map { |el| normalize_values(el) }
    when Hash
      obj.transform_values do |v|
        if v.is_a?(Hash) || v.is_a?(Array)
          normalize_values(v)
        elsif v.nil?
          nil
        else
          v.to_s
        end
      end
    else
      obj.to_s
    end
  end
end
