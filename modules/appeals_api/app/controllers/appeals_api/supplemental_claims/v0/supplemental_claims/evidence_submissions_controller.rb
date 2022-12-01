# frozen_string_literal: true

module AppealsApi::SupplementalClaims::V0::SupplementalClaims
  # rubocop:disable Layout/LineLength
  class EvidenceSubmissionsController < AppealsApi::V2::DecisionReviews::SupplementalClaims::EvidenceSubmissionsController
    # rubocop:enable Layout/LineLength
    include AppealsApi::OpenidAuth
  end
end
