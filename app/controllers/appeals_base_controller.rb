# frozen_string_literal: true

class AppealsBaseController < ApplicationController
  include ActionController::Serialization
  before_action { authorize :appeals, :access? }

  rescue_from DecisionReview::RequestSchemaError do |e|
    render_schema_error_exception e, status: 400
  end

  rescue_from DecisionReview::ResponseSchemaError do |e|
    render_schema_error_exception e, status: 502
  end

  private

  def appeals_service
    Caseflow::Service.new
  end

  def render_schema_error_exception(exception, status:)
    render json: { errors: schema_errors_to_json_api(exception.errors) }, status: status
  end

  def schema_errors_to_json_api(errors)
    json_schemer_errors, other_errors = errors.partition { |error| error.key? 'schema' }

    other_errors + JsonSchema::JsonApiMissingAttribute.new(json_schemer_errors)
                                                      .to_json_api[:errors]
                                                      .map { |error| error.except :status }
  end
end
