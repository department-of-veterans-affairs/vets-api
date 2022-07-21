# frozen_string_literal: true

require 'hca/service'

module V0
  class HealthCareApplicationsController < ApplicationController
    FORM_ID = '1010ez'

    skip_before_action(:authenticate)

    before_action :record_submission_attempt, only: :create

    def create
      load_user

      health_care_application = HealthCareApplication.new(params.permit(:form))
      health_care_application.async_compatible = params[:async_all]
      health_care_application.google_analytics_client_id = params[:ga_client_id]
      health_care_application.user = current_user

      result = health_care_application.process!

      clear_saved_form(FORM_ID)

      render(json: result)
    end

    def show
      render(json: HealthCareApplication.find(params[:id]))
    end

    def enrollment_status
      load_user
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

    def record_submission_attempt
      StatsD.increment("#{HCA::Service::STATSD_KEY_PREFIX}.submission_attempt")
    end

    def skip_sentry_exception_types
      super + [Common::Exceptions::BackendServiceException]
    end
  end
end
