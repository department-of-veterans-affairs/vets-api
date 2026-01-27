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

      # The final resting place options
      RESTING_PLACES = {
        'cemetery' => 0,
        'mausoleum' => 1,
        'privateResidence' => 2,
        'other' => 3
      }.freeze

      # The cemetery location options
      CEMETARY_LOCATION = {
        'cemetery' => 0,
        'tribalLand' => 1,
        'none' => 2
      }.freeze
    end
  end
end
