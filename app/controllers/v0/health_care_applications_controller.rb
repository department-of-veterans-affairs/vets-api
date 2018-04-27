# frozen_string_literal: true

require 'hca/service'

module V0
  class HealthCareApplicationsController < ApplicationController
    FORM_ID = '10-10EZ'
    # We call authenticate_token because auth is optional on this endpoint.
    skip_before_action(:authenticate)
    before_action(:tag_rainbows)

    def create
      authenticate_token

      form = JSON.parse(params[:form])
      validate!(form)

      health_care_application = HealthCareApplication.create!

      HCA::SubmissionJob.perform_async(current_user&.uuid, form, health_care_application.id)
      clear_saved_form(FORM_ID)

      render(json: health_care_application)
    end

    def show
      render(json: HealthCareApplication.find(params[:id]))
    end

    def healthcheck
      render(json: HCA::Service.new.health_check)
    end

    private

    def skip_sentry_exception_types
      super + [Common::Exceptions::GatewayTimeout]
    end

    def validate!(form)
      validation_errors = JSON::Validator.fully_validate(
        VetsJsonSchema::SCHEMAS[FORM_ID],
        form, validate_schema: true
      )

      raise Common::Exceptions::SchemaValidationErrors, validation_errors if validation_errors.present?
    end
  end
end
