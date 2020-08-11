# frozen_string_literal: true

module Preneeds
  class Race < Preneeds::Base
    # I American Indian or Alaskan Native
    # A Asian
    # B Black or African American
    # H Hispanic or Latino
    # U Not Hispanic or Latino
    # P Native Hawaiian or Other Pacific Islander
    # W White
    # TODO validate
    attribute :race_cd, String

    def as_eoas
      {
        raceCd: race_cd
      }
    end
  end
end
