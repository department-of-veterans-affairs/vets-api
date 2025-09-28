# frozen_string_literal: true

require 'rails_helper'
require 'lib/pdf_fill/fill_form_examples'
require 'survivors_benefits/pdf_fill/Va21p534ez'
require 'fileutils'
require 'tmpdir'
require 'timecop'

def basic_class
  SurvivorsBenefits::PdfFill::Va21p534ez.new({})
end

def test_data_types
  %w[kitchen_sink overflow simple]
end

describe SurvivorsBenefits::PdfFill::Va21p534ez, skip: 'TODO after schema built' do
  include SchemaMatchers

  let(:form_data) do
    VetsJsonSchema::EXAMPLES.fetch('21P-534EZ')
  end

  context "with #{test_data_types.join(', ')}" do
    it_behaves_like 'a form filler', {
      form_id: SurvivorsBenefits::FORM_ID,
      factory: :survivors_benefits_claim,
      use_vets_json_schema: true,
      input_data_fixture_dir: "modules/survivors_benefits/spec/fixtures/pdf_fill/#{SurvivorsBenefits::FORM_ID}",
      output_pdf_fixture_dir: "modules/survivors_benefits/spec/fixtures/pdf_fill/#{SurvivorsBenefits::FORM_ID}",
      test_data_types:,
      fill_options: { extras_redesign: true, omit_esign_stamp: true }
    }
  end

  describe '#merge_fields' do
    it 'merges the right fields' do
      Timecop.freeze(Time.zone.parse('2016-12-31 00:00:00 EDT')) do
        expected = get_fixture_absolute(
          'modules/survivors_benefits/spec/fixtures/pdf_fill/21P-534EZ/merge_fields'
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
