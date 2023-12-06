# frozen_string_literal: true

require 'rails_helper'
require 'pdf_fill/forms/va21p527ezare'

def basic_class
  PdfFill::Forms::Va21p527ezare.new({})
end

describe PdfFill::Forms::Va21p527ezare do
  include SchemaMatchers

  let(:form_data) do
    get_fixture('pdf_fill/21P-527EZ-ARE/kitchen_sink')
  end

  describe '#merge_fields' do
    it 'merges the right fields', run_at: '2016-12-31 00:00:00 EDT' do
      expect(described_class.new(form_data).merge_fields.to_json).to eq(
        get_fixture('pdf_fill/21P-527EZ-ARE/merge_fields').to_json
      )
    end
  end
end
