# frozen_string_literal: true

require 'rails_helper'
require 'pdf_fill/forms/va1010ezr'
require 'lib/pdf_fill/fill_form_examples'

describe PdfFill::Forms::Va2210275 do
  include SchemaMatchers

  let(:form_data) do
    get_fixture('pdf_fill/22-10275/kitchen_sink')
  end
end
