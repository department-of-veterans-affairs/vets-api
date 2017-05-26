# frozen_string_literal: true
require 'hca/voa/service'

module V0
  class HealthCareApplicationsController < ApplicationController
    # We call authenticate_token because auth is optional on this endpoint.
    skip_before_action(:authenticate)

    def create
      authenticate_token

      form = JSON.parse(params[:form])
      validate!(form)

      result = begin
        HCA::VOA::Service.new(current_user).submit_form(form)
      rescue Common::Client::Errors::ClientError => e
        log_exception_to_sentry(e)

        raise Common::Exceptions::BackendServiceException.new(
          nil, detail: e.message
        )
      end
      Rails.logger.info "SubmissionID=#{result[:formSubmissionId]}"
      render(json: result)
    end

    def healthcheck
      render(json: HCA::VOA::Service.new.health_check)
    end

    private

    def validate!(form)
      validation_errors = JSON::Validator.fully_validate(
        VetsJsonSchema::SCHEMAS['10-10EZ'],
        form, validate_schema: true
      )

      if validation_errors.present?
        log_message_to_sentry(validation_errors.join(','), :error, {}, validation: 'health_care_application')
        raise Common::Exceptions::SchemaValidationErrors, validation_errors
      end
    end
  end
end
