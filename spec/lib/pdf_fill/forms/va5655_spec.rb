# frozen_string_literal: true

require 'rails_helper'
require 'pdf_fill/forms/va5655'
require 'pdf_fill/filler'
require 'lib/pdf_fill/fill_form_examples'

describe PdfFill::Forms::Va5655 do
  describe '#merge_fields' do
    it 'merges the right fields', run_at: '2016-12-31 00:00:00 EDT' do
      expect(described_class.new(get_fixture('pdf_fill/5655/simple')).merge_fields).to eq(
        get_fixture('pdf_fill/5655/merge_fields')
      )
    end
  end
end
