# frozen_string_literal: true

require 'appeals_api/form_schemas'

module AppealsApi::HigherLevelReviews::V0
  class HigherLevelReviewsController < AppealsApi::V2::DecisionReviews::HigherLevelReviewsController
    include AppealsApi::OpenidAuth

    FORM_NUMBER = '200996_WITH_SHARED_REFS'
    API_VERSION = 'V0'
    SCHEMA_VERSION = 'v2'
    HEADERS = JSON.parse(
      File.read(
        AppealsApi::Engine.root.join('config/schemas/v2/200996_with_shared_refs_headers.json')
      )
    )['definitions']['hlrCreateParameters']['properties'].keys

    OAUTH_SCOPES = {
      GET: %w[veteran/HigherLevelReviews.read representative/HigherLevelReviews.read system/HigherLevelReviews.read],
      PUT: %w[veteran/HigherLevelReviews.write representative/HigherLevelReviews.write system/HigherLevelReviews.write],
      POST: %w[veteran/HigherLevelReviews.write representative/HigherLevelReviews.write system/HigherLevelReviews.write]
    }.freeze

    private

    def token_validation_api_key
      Settings.dig(:modules_appeals_api, :token_validation, :higher_level_reviews, :api_key)
    end
  end
end
