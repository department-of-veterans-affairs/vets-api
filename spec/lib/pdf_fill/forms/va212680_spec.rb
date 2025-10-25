# frozen_string_literal: true

require 'rails_helper'
require 'pdf_fill/forms/va1010cg'
require 'lib/pdf_fill/fill_form_examples'

describe PdfFill::Forms::Va212680 do
  # include SchemaMatchers

  # before do
  #   # create health_facility record used for plannedClinic field on 10-10CG pdf form specs
  #   create(:health_facility, name: 'Harlingen VA Clinic',
  #                            station_number: '740',
  #                            postal_name: 'TX')
  # end

  # let(:form_data) do
  #   get_fixture('pdf_fill/21-2680/simple')
  # end

  let(:form_class) do
    PdfFill::Forms::Va212680.new(form_data)
  end

  it_behaves_like 'a form filler', {
    form_id: '21-2680',
    factory: :va12680,
    input_data_fixture_dir: 'spec/fixtures/pdf_fill/21-2680',
    output_pdf_fixture_dir: 'spec/fixtures/pdf_fill/21-2680',
    test_data_types: %w[simple],
    run_at: '2025-10-24T18:48:27Z'
  }
end
