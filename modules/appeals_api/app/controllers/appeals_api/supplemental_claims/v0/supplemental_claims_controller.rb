# frozen_string_literal: true

require 'appeals_api/form_schemas'

module AppealsApi::SupplementalClaims::V0
  class SupplementalClaimsController < AppealsApi::V2::DecisionReviews::SupplementalClaimsController
    include AppealsApi::OpenidAuth

    API_VERSION = 'V0'
    SCHEMA_OPTIONS = { schema_version: 'v0', api_name: 'supplemental_claims' }.freeze

    OAUTH_SCOPES = {
      GET: %w[veteran/SupplementalClaims.read representative/SupplementalClaims.read system/SupplementalClaims.read],
      PUT: %w[veteran/SupplementalClaims.write representative/SupplementalClaims.write system/SupplementalClaims.read],
      POST: %w[veteran/SupplementalClaims.write representative/SupplementalClaims.write system/SupplementalClaims.read]
    }.freeze

    private

    def token_validation_api_key
      Settings.dig(:modules_appeals_api, :token_validation, :supplemental_claims, :api_key)
    end
  end
end
