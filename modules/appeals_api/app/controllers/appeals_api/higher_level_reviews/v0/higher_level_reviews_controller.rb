# frozen_string_literal: true

require 'appeals_api/form_schemas'

module AppealsApi::HigherLevelReviews::V0
  class HigherLevelReviewsController < AppealsApi::V2::DecisionReviews::HigherLevelReviewsController
    include AppealsApi::OpenidAuth
    include AppealsApi::PdfDownloads

    skip_before_action :validate_icn_header
    skip_before_action :new_higher_level_review
    skip_before_action :find_higher_level_review

    before_action :validate_icn_parameter, only: %i[download]

    API_VERSION = 'V0'
    SCHEMA_OPTIONS = { schema_version: 'v0', api_name: 'higher_level_reviews' }.freeze

    OAUTH_SCOPES = {
      GET: %w[veteran/HigherLevelReviews.read representative/HigherLevelReviews.read system/HigherLevelReviews.read],
      PUT: %w[veteran/HigherLevelReviews.write representative/HigherLevelReviews.write system/HigherLevelReviews.write],
      POST: %w[veteran/HigherLevelReviews.write representative/HigherLevelReviews.write system/HigherLevelReviews.write]
    }.freeze

    def show
      hlr = AppealsApi::HigherLevelReview.select(ALLOWED_COLUMNS).find(params[:id])
      hlr = with_status_simulation(hlr) if status_requested_and_allowed?

      render_higher_level_review(hlr)
    rescue ActiveRecord::RecordNotFound
      render_higher_level_review_not_found(params[:id])
    end

    def create
      hlr = AppealsApi::HigherLevelReview.new(
        auth_headers: request_headers,
        form_data: @json_body,
        source: request_headers['X-Consumer-Username'].presence&.strip,
        api_version: self.class::API_VERSION,
        veteran_icn: @json_body.dig('data', 'attributes', 'veteran', 'icn')
      )

      return render_model_errors(hlr) unless hlr.validate

      hlr.save
      AppealsApi::PdfSubmitJob.perform_async(hlr.id, 'AppealsApi::HigherLevelReview', 'v3')

      render_higher_level_review(hlr)
    end

    def download
      @id = params[:id]
      @higher_level_review = AppealsApi::HigherLevelReview.find(@id)

      render_appeal_pdf_download(@higher_level_review, "#{FORM_NUMBER}-higher-level-review-#{@id}.pdf", params[:icn])
    rescue ActiveRecord::RecordNotFound
      render_higher_level_review_not_found(params[:id])
    end

    private

    def header_names = headers_schema['definitions']['hlrCreateParameters']['properties'].keys

    def render_higher_level_review(hlr)
      render json: AppealsApi::HigherLevelReviewSerializer.new(hlr).serializable_hash
    end

    def render_higher_level_review_not_found(id)
      render(
        status: :not_found,
        json: {
          errors: [
            {
              code: '404',
              detail: I18n.t('appeals_api.errors.not_found', type: 'HigherLevelReview', id:),
              status: '404',
              title: 'Record not found'
            }
          ]
        }
      )
    end

    def render_model_errors(hlr)
      render json: model_errors_to_json_api(hlr), status: MODEL_ERROR_STATUS
    end

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
