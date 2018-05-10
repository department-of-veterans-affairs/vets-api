# frozen_string_literal: true

class V0::DependentsApplicationsController < ApplicationController
  FORM_ID = '21-686C'
  skip_before_action(:authenticate)
  before_action(:tag_rainbows)

  def create
    form = JSON.parse(params[:form])
    validate!(form)
    render json: {}
  end

  private

  def validate!(form)
    validation_errors = JSON::Validator.fully_validate(
      VetsJsonSchema::SCHEMAS[FORM_ID],
      form, validate_schema: true
    )

    raise Common::Exceptions::SchemaValidationErrors, validation_errors if validation_errors.present?
  end
end
