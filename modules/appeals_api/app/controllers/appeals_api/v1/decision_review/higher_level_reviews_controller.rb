# frozen_string_literal: true

require 'json_schema/json_api_missing_attribute'
require 'appeals_api/form_schemas'
require_dependency 'appeals_api/concerns/json_format_validation'

class AppealsApi::V1::DecisionReview::HigherLevelReviewsController < AppealsApi::ApplicationController
  include AppealsApi::JsonFormatValidation

  skip_before_action(:authenticate)
  before_action :validate_json_format, if: -> { request.post? }
  before_action :validate_json_schema, only: %i[create validate]

  FORM_NUMBER = '200996'
  CREATE_HEADERS = YAML.safe_load(
    File.read(AppealsApi::Engine.root.join('app/swagger/v1/decision_reviews.yaml'))
  )['paths']['/higher_level_reviews']['post']['parameters'].map { |parameter| parameter['name'] }

  def create
    higher_level_review = AppealsApi::HigherLevelReview.create!(
      auth_headers: create_headers,
      form_data: @json_body
    )
    AppealsApi::HigherLevelReviewPdfSubmitJob.perform_async(higher_level_review.id)
    render json: higher_level_review, serializer: AppealsApi::HigherLevelReviewSerializer
  end

  def validate
    render json: validation_success
  end

  def schema
    render json: { data: [AppealsApi::FormSchemas.new.schemas[self.class::FORM_NUMBER]] }
  end

  private

  def validate_json_schema
    AppealsApi::FormSchemas.new.validate!(self.class::FORM_NUMBER, @json_body)
  rescue JsonSchema::JsonApiMissingAttribute => e
    render json: e.to_json_api, status: e.code
  end

  def validation_success
    {
      data: {
        type: 'appeals_api_higher_level_review_validation',
        attributes: {
          status: 'valid'
        }
      }
    }
  end

  def create_headers
    CREATE_HEADERS.reduce({}) do |hash, key|
      hash.merge({ key => request.headers[key] })
    end
  end
end
