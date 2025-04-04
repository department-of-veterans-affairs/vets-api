# frozen_string_literal: true

require 'rails_helper'
require 'income_and_assets/pdf_fill/forms/va21p0969'

def basic_class
  PdfFill::Forms::Va21p0969.new({})
end

describe PdfFill::Forms::Va21p0969 do
  include SchemaMatchers

  let(:form_data) do
    VetsJsonSchema::EXAMPLES.fetch('21P-0969-KITCHEN_SINK')
  end

  describe '#merge_fields' do
    it 'merges the right fields', run_at: '2016-12-31 00:00:00 EDT' do
      expect(described_class.new(form_data).merge_fields.to_json).to eq(
        get_fixture_absolute('modules/income_and_assets/spec/fixtures/pdf_fill/21P-0969/merge_fields').to_json
      )
    end
  end
end
