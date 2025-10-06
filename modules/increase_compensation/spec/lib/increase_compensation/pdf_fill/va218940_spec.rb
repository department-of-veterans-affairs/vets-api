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
  %w[kitchen_sink overflow simple]
end

describe IncreaseCompensation::PdfFill::Va218940, skip: 'TODO after schema built' do
  include SchemaMatchers

  let(:form_data) do
    VetsJsonSchema::EXAMPLES.fetch('21P-8416-KITCHEN_SINK')
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
    it 'merges the right fields' do
      Timecop.freeze(Time.zone.parse('2016-12-31 00:00:00 EDT')) do
        expected = get_fixture_absolute(
          'modules/increase_compensation/spec/fixtures/pdf_fill/21P-8416/merge_fields'
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
