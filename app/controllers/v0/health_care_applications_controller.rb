# frozen_string_literal: true

module V0
  class HealthCareApplicationsController < ApplicationController
    FORM_ID = '1010ez'

    skip_before_action(:authenticate)
    before_action(:append_to_skip_sentry_exception_types)
    after_action(:remove_from_skip_sentry_exception_types)

    def create
      validate_session

      health_care_application = HealthCareApplication.new(params.permit(:form))
      health_care_application.async_compatible = params[:async_compatible]
      health_care_application.google_analytics_client_id = params[:ga_client_id]
      health_care_application.user = current_user

      result = health_care_application.process!

      clear_saved_form(FORM_ID)

      render(json: result)
    end

    def enrollment_status
      validate_session
      loa3 = current_user&.loa3?

      icn =
        if loa3
          current_user.icn
        else
          HealthCareApplication.user_icn(
            HealthCareApplication.user_attributes(params[:userAttributes])
          )
        end

      raise Common::Exceptions::RecordNotFound, nil if icn.blank?

      render(json: HealthCareApplication.enrollment_status(icn, loa3))
    end

    def healthcheck
      render(json: HCA::Service.new.health_check)
    end

    private
    
    def sentry_skip_types
      [Common::Exceptions::BackendServiceException]
    end

    def append_to_skip_sentry_exception_types
      Raven::Configuration::IGNORE_DEFAULT += sentry_skip_types
    end
    
    def remove_from_skip_sentry_exception_types
      Raven::Configuration::IGNORE_DEFAULT -= sentry_skip_types
    end
  end
end
