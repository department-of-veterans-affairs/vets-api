# frozen_string_literal: true

module Burials
  module PdfFill
    # Constants used for PDF mapping
    module Constants
      # The Recipients Type
      RELATIONSHIPS = {
        'spouse' => 0,
        'child' => 1,
        'parent' => 2,
        'executor' => 3,
        'funeralDirector' => 4,
        'otherFamily' => 5
      }.freeze
    end
  end
end
