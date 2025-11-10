# frozen_string_literal: true

require 'pdf_fill/forms/form_base'
require 'pdf_fill/forms/form_helper'

module PdfFill
  module Forms
    class Va210779 < FormBase
      LEVEL_OF_CARE = %w[skilled intermediate].freeze
      KEY = {}.freeze
      # KEY = FieldMappings::Va210779::KEY
    end
  end
end
