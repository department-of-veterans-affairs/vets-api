# frozen_string_literal: true
require 'hca/service'

module V0
  class HealthCareApplicationsController < ApplicationController
    # We call authenticate_token because auth is optional on this endpoint.
    skip_before_action(:authenticate)

    def create
      form = JSON.parse(params[:form])
      validation_errors = JSON::Validator.fully_validate(
        VetsJsonSchema::SCHEMAS['10-10EZ'],
        form, validate_schema: true
      )

      if validation_errors.present?
        raise Common::Exceptions::SchemaValidationErrors, validation_errors
      end

      authenticate_token

      result = begin
        HCA::Service.new(current_user).submit_form(form)
      rescue Common::Client::Errors::ClientError => e
        log_exception_to_sentry(e)

        raise Common::Exceptions::BackendServiceException.new(
          nil,
          detail: e.message
        )
      end
      Rails.logger.info "SubmissionID=#{result[:formSubmissionId]}"
      render(json: result)
    end

    def healthcheck
      render(json: HCA::Service.new.health_check)
    end
  end
end
