# frozen_string_literal: true

require 'rails_helper'
require 'lib/pdf_fill/fill_form_examples'
require 'income_and_assets/pdf_fill/va21p0969'
require 'fileutils'
require 'tmpdir'

def basic_class
  IncomeAndAssets::PdfFill::Va21p0969.new({})
end

describe IncomeAndAssets::PdfFill::Va21p0969 do
  include SchemaMatchers

  let(:form_data) do
    VetsJsonSchema::EXAMPLES.fetch('21P-0969-KITCHEN_SINK')
  end

  [
    { test_data_types: %w[simple kitchen_sink], extras_redesign: false },
    { test_data_types: %w[overflow], extras_redesign: false },
    { test_data_types: %w[overflow], extras_redesign: true }
  ].each do |config|
    context "with #{config[:test_data_types].join(', ')} and extras_redesign: #{config[:extras_redesign]}" do
      it_behaves_like 'a form filler', {
        form_id: IncomeAndAssets::FORM_ID,
        factory: :income_and_assets_claim,
        use_vets_json_schema: true,
        input_data_fixture_dir: "modules/income_and_assets/spec/fixtures/pdf_fill/#{IncomeAndAssets::FORM_ID}",
        output_pdf_fixture_dir: "modules/income_and_assets/spec/fixtures/pdf_fill/#{IncomeAndAssets::FORM_ID}",
        test_data_types: config[:test_data_types],
        fill_options: config[:extras_redesign] ? { extras_redesign: true } : {}
      }
    end
  end

  describe '#merge_fields' do
    it 'merges the right fields', run_at: '2016-12-31 00:00:00 EDT' do
      expect(described_class.new(form_data).merge_fields.to_json).to eq(
        get_fixture_absolute('modules/income_and_assets/spec/fixtures/pdf_fill/21P-0969/merge_fields').to_json
      )
    end
  end
end
