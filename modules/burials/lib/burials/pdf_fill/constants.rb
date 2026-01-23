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

<<<<<<< HEAD
      # The final resting place options
=======
>>>>>>> fc33d785f3 (Add Section 4 V2)
      RESTING_PLACES = {
        'cemetery' => 0,
        'mausoleum' => 1,
        'privateResidence' => 2,
        'other' => 3
      }.freeze

<<<<<<< HEAD
      # The cemetery location options
=======
>>>>>>> fc33d785f3 (Add Section 4 V2)
      CEMETARY_LOCATION = {
        'cemetery' => 0,
        'tribalLand' => 1,
        'none' => 2
      }.freeze
    end
  end
end
