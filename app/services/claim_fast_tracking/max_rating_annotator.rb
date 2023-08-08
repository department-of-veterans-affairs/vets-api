# frozen_string_literal: true

module ClaimFastTracking
  class MaxRatingAnnotator
    def self.annotate_disabilities(rated_disabilities_response)
      tinnitus = ClaimFastTracking::DiagnosticCodes::TINNITUS
      rated_disabilities_response.rated_disabilities.each do |disability|
        disability.maximum_rating_percentage = 10 if disability.diagnostic_code == tinnitus
      end
    end
  end
end
