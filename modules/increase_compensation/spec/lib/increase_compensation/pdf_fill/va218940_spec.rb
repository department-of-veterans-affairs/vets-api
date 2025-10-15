# frozen_string_literal: true

require 'rails_helper'
require 'lib/pdf_fill/fill_form_examples'
require 'increase_compensation/pdf_fill/va218940'
require 'fileutils'
require 'tmpdir'
require 'timecop'

def basic_class
  IncreaseCompensation::PdfFill::Va218940.new({})
end

def test_data_types
  %w[kitchen_sink]
end

describe IncreaseCompensation::PdfFill::Va218940, skip: 'TODO after schema built' do
  include SchemaMatchers

  describe '#to_pdf' do
    it 'merges the right keys' do
      f1 = File.read File.join(__dir__, '21-8940_kitchen-sink.json')

      claim = IncreaseCompensation::SavedClaim.new(form: JSON.parse(f1).to_s)

      form_id = IncreaseCompensation::FORM_ID
      form_class = IncreaseCompensation::PdfFill::Va218940
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

  context "with #{test_data_types.join(', ')}" do
    it_behaves_like 'a form filler', {
      form_id: IncreaseCompensation::FORM_ID,
      factory: :increase_compensation_claim,
      use_vets_json_schema: true,
      input_data_fixture_dir: "modules/increase_compensation/spec/fixtures/pdf_fill/#{IncreaseCompensation::FORM_ID}",
      output_pdf_fixture_dir: "modules/increase_compensation/spec/fixtures/pdf_fill/#{IncreaseCompensation::FORM_ID}",
      test_data_types:,
      fill_options: { extras_redesign: true, omit_esign_stamp: true }
    }
  end

  describe '#merge_fields' do
    let(:form_data) do
      VetsJsonSchema::EXAMPLES.fetch('21-8940')
    end

    it 'merges the right fields' do
      Timecop.freeze(Time.zone.parse('2016-12-31 00:00:00 EDT')) do
        expected = get_fixture_absolute(
          'modules/increase_compensation/spec/fixtures/pdf_fill/21-8940/merge_fields'
        )

        expected = JSON.parse(File.read(expected)) unless expected.is_a?(Hash)

        actual = described_class.new(form_data).merge_fields

        expect(normalize_values(actual)).to match_array(normalize_values(expected))
      end
    ensure
      Timecop.return
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
