# frozen_string_literal: true

require 'rails_helper'
require 'lib/pdf_fill/fill_form_examples'
require 'income_and_assets/pdf_fill/va21p0969'
require 'fileutils'
require 'tmpdir'
require 'timecop'

def basic_class
  IncomeAndAssets::PdfFill::Va21p0969.new({})
end

def test_data_types
  %w[kitchen_sink overflow simple]
end

describe IncomeAndAssets::PdfFill::Va21p0969 do
  include SchemaMatchers

  let(:form_data) do
    VetsJsonSchema::EXAMPLES.fetch('21P-0969-KITCHEN_SINK')
  end

  context "with #{test_data_types.join(', ')}" do
    it_behaves_like 'a form filler', {
      form_id: IncomeAndAssets::FORM_ID,
      factory: :income_and_assets_claim,
      use_vets_json_schema: true,
      input_data_fixture_dir: "modules/income_and_assets/spec/fixtures/pdf_fill/#{IncomeAndAssets::FORM_ID}",
      output_pdf_fixture_dir: "modules/income_and_assets/spec/fixtures/pdf_fill/#{IncomeAndAssets::FORM_ID}",
      test_data_types:,
      fill_options: { extras_redesign: true, omit_esign_stamp: true }
    }
  end

  describe '#merge_fields' do
    it 'merges the right fields' do
      Timecop.freeze(Time.zone.parse('2016-12-31 00:00:00 EDT')) do
        expected = get_fixture_absolute(
          'modules/income_and_assets/spec/fixtures/pdf_fill/21P-0969/merge_fields'
        )

        expected = JSON.parse(File.read(expected)) unless expected.is_a?(Hash)
        actual = described_class.new(form_data).merge_fields

        # Create a diff that is easy to read when expected/actual differ
        diff = Hashdiff.diff(normalize_values(expected), normalize_values(actual))

        expect(diff).to eq([])
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
