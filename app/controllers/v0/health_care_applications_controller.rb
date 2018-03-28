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

      result = begin
        HCA::Service.new(current_user).submit_form(form)
      rescue Common::Client::Errors::ClientError => e
        log_exception_to_sentry(e)

        raise Common::Exceptions::BackendServiceException.new(
          nil, detail: e.message
        )
      end

      clear_saved_form(FORM_ID)

      Rails.logger.info "SubmissionID=#{result[:formSubmissionId]}"
      render(json: result)
    end

    def healthcheck
      render(json: HCA::Service.new.health_check)
    end

    private

    def validate!(form)
      validation_errors = JSON::Validator.fully_validate(
        VetsJsonSchema::SCHEMAS[FORM_ID],
        form, validate_schema: true
      )

      if validation_errors.present?
        raise Common::Exceptions::SchemaValidationErrors, validation_errors
      end
    end
  end
end
