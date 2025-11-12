# frozen_string_literal: true

require 'rails_helper'
require 'lib/pdf_fill/fill_form_examples'

describe PdfFill::Forms::Va210779 do
  it_behaves_like 'a form filler', {
    form_id: '21-0779',
    factory: :va210779_countries,
    use_vets_json_schema: true,
    test_data_types: %w[simple],
    run_at: '2025-10-24T18:48:27Z'
  }
end
