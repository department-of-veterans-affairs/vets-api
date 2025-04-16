# frozen_string_literal: true

require 'rails_helper'
require 'lib/pdf_fill/fill_form_examples'

describe PdfFill::Filler, type: :model do
  it_behaves_like 'a form filler', {
    form_id: IncomeAndAssets::FORM_ID,
    factory: :income_and_assets_claim,
    use_vets_json_schema: true,
    input_data_fixture_dir: "modules/income_and_assets/spec/fixtures/pdf_fill/#{IncomeAndAssets::FORM_ID}",
    output_pdf_fixture_dir: "modules/income_and_assets/spec/fixtures/pdf_fill/#{IncomeAndAssets::FORM_ID}",
    test_data_types: %w[simple kitchen_sink overflow]
  }
end
