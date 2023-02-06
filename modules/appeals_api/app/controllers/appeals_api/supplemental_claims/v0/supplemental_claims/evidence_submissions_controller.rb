# frozen_string_literal: true

module AppealsApi::SupplementalClaims::V0::SupplementalClaims
  # rubocop:disable Layout/LineLength
  class EvidenceSubmissionsController < AppealsApi::V2::DecisionReviews::SupplementalClaims::EvidenceSubmissionsController
    # rubocop:enable Layout/LineLength
    include AppealsApi::OpenidAuth

    OAUTH_SCOPES = {
      GET: %w[appeals/SupplementalClaims.read],
      PUT: %w[appeals/SupplementalClaims.write],
      POST: %w[appeals/SupplementalClaims.write]
    }.freeze

    private

    def token_validation_api_key
      Settings.dig(:modules_appeals_api, :token_validation, :supplemental_claims, :api_key)
    end
  end
end
