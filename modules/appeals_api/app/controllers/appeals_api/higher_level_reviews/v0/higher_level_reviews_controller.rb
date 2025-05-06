# frozen_string_literal: true

require 'appeals_api/form_schemas'

module AppealsApi::HigherLevelReviews::V0
  class HigherLevelReviewsController < AppealsApi::ApplicationController
    include AppealsApi::CharacterUtilities
    include AppealsApi::IcnParameterValidation
    include AppealsApi::JsonFormatValidation
    include AppealsApi::MPIVeteran
    include AppealsApi::OpenidAuth
    include AppealsApi::PdfDownloads
    include AppealsApi::Schemas
    include AppealsApi::StatusSimulation

    skip_before_action :authenticate
    before_action :validate_json_body, if: -> { request.post? }
    before_action :validate_json_schema, only: %i[create validate]
    before_action :validate_icn_parameter!, only: %i[download index]

    FORM_NUMBER = '200996'
    API_VERSION = 'V0'
    MODEL_ERROR_STATUS = 422
    SCHEMA_OPTIONS = { schema_version: 'v0', api_name: 'higher_level_reviews' }.freeze

    OAUTH_SCOPES = {
      GET: %w[veteran/HigherLevelReviews.read representative/HigherLevelReviews.read system/HigherLevelReviews.read],
      PUT: %w[veteran/HigherLevelReviews.write representative/HigherLevelReviews.write system/HigherLevelReviews.write],
      POST: %w[veteran/HigherLevelReviews.write representative/HigherLevelReviews.write system/HigherLevelReviews.write]
    }.freeze

    def schema
      render json: AppealsApi::JsonSchemaToSwaggerConverter.remove_comments(form_schema)
    end

    # NOTE: index route is disabled until questions around claimant vs. veteran privacy are resolved
    def index
      render_higher_level_review(AppealsApi::HigherLevelReview.where(veteran_icn:).order(created_at: :desc))
    end

    def show
      hlr = AppealsApi::HigherLevelReview.find(params[:id])
      validate_token_icn_access!(hlr.veteran_icn)

      hlr = with_status_simulation(hlr) if status_requested_and_allowed?

      render_higher_level_review(hlr)
    rescue ActiveRecord::RecordNotFound
      render_higher_level_review_not_found(params[:id])
    end

    def validate
      render json: {
        data: {
          type: 'higherLevelReviewValidation',
          attributes: {
            status: 'valid'
          }
        }
      }
    end

    def create
      submitted_icn = @json_body.dig('data', 'attributes', 'veteran', 'icn')
      validate_token_icn_access!(submitted_icn)

      hlr = AppealsApi::HigherLevelReview.new(
        auth_headers: request_headers,
        form_data: @json_body,
        source: request_headers['X-Consumer-Username'].presence&.strip,
        api_version: self.class::API_VERSION,
        veteran_icn: submitted_icn
      )

      return render_model_errors(hlr) unless hlr.validate

      hlr.save
      AppealsApi::PdfSubmitJob.perform_async(hlr.id, 'AppealsApi::HigherLevelReview', 'v3')

      render_higher_level_review(hlr, include_pii: true, status: :created)
    end

    def download
      render_appeal_pdf_download(
        AppealsApi::HigherLevelReview.find(params[:id]),
        "#{FORM_NUMBER}-higher-level-review-#{params[:id]}.pdf",
        veteran_icn
      )
    rescue ActiveRecord::RecordNotFound
      render_higher_level_review_not_found(params[:id])
    end

    private

    def header_names = headers_schema['definitions']['hlrCreateParameters']['properties'].keys

    def validate_json_schema
      begin
        validate_headers(request_headers)
        validate_form_data(@json_body)
      rescue JsonSchema::JsonApiMissingAttribute => e
        render json: e.to_json_api, status: e.code
      end

      status, error = AppealsApi::HigherLevelReviews::PdfFormFieldV2Validator.new(@json_body, headers).validate!
      return if error.blank?

      render status:, json: error
    end

    def request_headers
      header_names.index_with { |key| request.headers[key] }.compact
    end

    def render_higher_level_review(hlr_or_hlrs, include_pii: false, **)
      serializer = (include_pii ? HigherLevelReviewSerializerWithPii : HigherLevelReviewSerializer).new(hlr_or_hlrs)
      render(json: serializer.serializable_hash, **)
    end

    def render_higher_level_review_not_found(id)
      raise Common::Exceptions::ResourceNotFound.new(
        detail: I18n.t('appeals_api.errors.not_found', type: 'Higher-Level Review', id:)
      )
    end

    def render_model_errors(hlr)
      render json: model_errors_to_json_api(hlr), status: MODEL_ERROR_STATUS
    end

    def token_validation_api_key
      Settings.modules_appeals_api.token_validation.higher_level_reviews.api_key
    end
  end
end
