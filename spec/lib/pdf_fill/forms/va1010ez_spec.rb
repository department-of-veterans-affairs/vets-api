# frozen_string_literal: true

require 'rails_helper'
require 'pdf_fill/forms/va1010ez'
require 'lib/pdf_fill/fill_form_examples'

describe PdfFill::Forms::Va1010ez do
  include SchemaMatchers

  let(:form_data) do
    get_fixture('pdf_fill/10-10EZ/simple')
  end

  let(:form_class) do
    described_class.new(form_data)
  end

  it_behaves_like 'a form filler', {
    form_id: described_class::FORM_ID,
    factory: :health_care_application,
    input_data_fixture_dir: 'spec/fixtures/pdf_fill/10-10EZ',
    output_pdf_fixture_dir: 'spec/fixtures/pdf_fill/10-10EZ/unsigned',
    test_data_types: %w[simple]
  }

  describe '#merge_fields' do
    it 'merges the right fields' do
      expect(form_class.merge_fields.to_json).to eq(
        get_fixture('pdf_fill/10-10EZ/merge_fields').to_json
      )
    end
  end
end
