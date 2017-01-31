# frozen_string_literal: true
require 'hca/service'

module V0
  class HealthCareApplicationsController < ApplicationController
    skip_before_action(:authenticate)

    def create
      form = JSON.parse(params[:form])
      validation_errors = JSON::Validator.fully_validate(
        VetsJsonSchema::HEALTHCARE_APPLICATION,
        form,
        validate_schema: true
      )

      if validation_errors.present?
        raise Common::Exceptions::SchemaValidationErrors, validation_errors
      end

      authenticate_token

      begin
        HCA::Service.new(@current_user).submit_form(form)
      rescue Common::Client::Errors::ClientError => e
        Raven.capture_exception(e)

        raise Common::Exceptions::BackendServiceException.new(
          nil,
          detail: e.message
        )
      end

      render(json: { success: true })
    end

    def healthcheck
      render(json: HCA::Service.new.health_check)
    end
  end
end
