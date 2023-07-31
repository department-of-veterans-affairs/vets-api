# frozen_string_literal: true

require 'appeals_api/form_schemas'

module AppealsApi::HigherLevelReviews::V0
  class HigherLevelReviewsController < AppealsApi::V2::DecisionReviews::HigherLevelReviewsController
    include AppealsApi::OpenidAuth
    include AppealsApi::PdfDownloads

    before_action :validate_icn_parameter, only: %i[download]

    API_VERSION = 'V0'
    SCHEMA_OPTIONS = { schema_version: 'v0', api_name: 'higher_level_reviews' }.freeze

    OAUTH_SCOPES = {
      GET: %w[veteran/HigherLevelReviews.read representative/HigherLevelReviews.read system/HigherLevelReviews.read],
      PUT: %w[veteran/HigherLevelReviews.write representative/HigherLevelReviews.write system/HigherLevelReviews.write],
      POST: %w[veteran/HigherLevelReviews.write representative/HigherLevelReviews.write system/HigherLevelReviews.write]
    }.freeze

    def download
      @id = params[:id]
      @higher_level_review = AppealsApi::HigherLevelReview.find(@id)

      render_appeal_pdf_download(@higher_level_review, "#{FORM_NUMBER}-higher-level-review-#{@id}.pdf")
    rescue ActiveRecord::RecordNotFound
      render_higher_level_review_not_found
    end

    private

    def header_names = headers_schema['definitions']['hlrCreateParameters']['properties'].keys

    def validate_icn_parameter
      validation_errors = []

      if params[:icn].blank?
        validation_errors << { status: 422, detail: "'icn' parameter is required" }
      elsif !ICN_REGEX.match?(params[:icn])
        validation_errors << { status: 422,
                               detail: "'icn' parameter has an invalid format. Pattern: #{ICN_REGEX.inspect}" }
      end

      render json: { errors: validation_errors }, status: :unprocessable_entity if validation_errors.present?
    end

    def token_validation_api_key
      Settings.dig(:modules_appeals_api, :token_validation, :higher_level_reviews, :api_key)
    end
  end
end
