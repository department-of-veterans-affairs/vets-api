# frozen_string_literal: true

require 'pdf_fill/hash_converter'
require 'pdf_fill/forms/form_base'

module PdfFill
  module Forms
    class Va212680 < FormBase
      RELATIONSHIPS = { 'self' => 1,
                        'spouse' => 2,
                        'parent' => 2,
                        'child' => 4 }.freeze

      BENEFITS = { 'smc' => 1,
                   'smp' => 2 }.freeze
    end
  end
end
