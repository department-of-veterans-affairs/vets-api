# frozen_string_literal: true

require 'appeals_api/form_schemas'

module AppealsApi::HigherLevelReviews::V0
  class HigherLevelReviewsController < AppealsApi::V2::DecisionReviews::HigherLevelReviewsController
    include AppealsApi::OpenidAuth

    API_VERSION = 'V0'
    SCHEMA_OPTIONS = { schema_version: 'v0', api_name: 'higher_level_reviews' }.freeze

    OAUTH_SCOPES = {
      GET: %w[veteran/HigherLevelReviews.read representative/HigherLevelReviews.read system/HigherLevelReviews.read],
      PUT: %w[veteran/HigherLevelReviews.write representative/HigherLevelReviews.write system/HigherLevelReviews.write],
      POST: %w[veteran/HigherLevelReviews.write representative/HigherLevelReviews.write system/HigherLevelReviews.write]
    }.freeze

    private

    def header_names = headers_schema['definitions']['hlrCreateParameters']['properties'].keys

    def token_validation_api_key
      Settings.dig(:modules_appeals_api, :token_validation, :higher_level_reviews, :api_key)
    end
  end
end
