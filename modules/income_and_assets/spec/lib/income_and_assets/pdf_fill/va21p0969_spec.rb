# frozen_string_literal: true

require 'rails_helper'
require 'lib/pdf_fill/fill_form_examples'
require 'income_and_assets/pdf_fill/va21p0969'

def basic_class
  IncomeAndAssets::PdfFill::Va21p0969.new({})
end

describe IncomeAndAssets::PdfFill::Va21p0969 do
  include SchemaMatchers

  let(:form_data) do
    VetsJsonSchema::EXAMPLES.fetch('21P-0969-KITCHEN_SINK')
  end

  # TODO: Once all of the sections have been merged, regenerate the PDF fixtures and
  # reenable this test (captured in ticket #106962)
  # it_behaves_like 'a form filler', {
  #   form_id: described_class::FORM_ID,
  #   factory: :income_and_assets_claim,
  #   use_vets_json_schema: true,
  #   input_data_fixture_dir: 'modules/income_and_assets/spec/fixtures/pdf_fill/21P-0969',
  #   output_pdf_fixture_dir: 'modules/income_and_assets/spec/fixtures/pdf_fill/21P-0969'
  # }

  describe '#merge_fields' do
    it 'merges the right fields', run_at: '2016-12-31 00:00:00 EDT' do
      # These are temporary changes and will be resolved as the mappings for the other sections get merged in
      # Section 10
      form_data.delete('unreportedAssets')

      expect(described_class.new(form_data).merge_fields.to_json).to eq(
        get_fixture_absolute('modules/income_and_assets/spec/fixtures/pdf_fill/21P-0969/merge_fields').to_json
      )
    end
  end
end
