# frozen_string_literal: true

require 'hca/service'
require 'bgs/service'

module V0
  class HealthCareApplicationsController < ApplicationController
    FORM_ID = '1010ez'

    skip_before_action(:authenticate, only: %i[create show enrollment_status healthcheck])

    before_action :record_submission_attempt, only: :create
    before_action :load_user, only: %i[create enrollment_status]

    def rating_info
      service = BGS::Service.new(current_user)
      disability_rating = service.find_rating_data[:disability_rating_record][:service_connected_combined_degree]

      render(
        json: {
          user_percent_of_disability: disability_rating
        },
        serializer: HCARatingInfoSerializer
      )
    end

    def create
      @health_care_application.async_compatible = params[:async_all]
      @health_care_application.google_analytics_client_id = params[:ga_client_id]
      @health_care_application.user = current_user

      begin
        result = @health_care_application.process!
      rescue HCA::SOAPParser::ValidationError
        raise Common::Exceptions::BackendServiceException.new('HCA422', status: 422)
      end

      clear_saved_form(FORM_ID)

      render(json: result)
    end

    def show
      render(json: HealthCareApplication.find(params[:id]))
    end

    def enrollment_status
      loa3 = current_user&.loa3?

      icn =
        if loa3
          current_user.icn
        else
          Raven.extra_context(
            user_loa: current_user&.loa
          )

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
      @health_care_application = HealthCareApplication.new(params.permit(:form))

      StatsD.increment("#{HCA::Service::STATSD_KEY_PREFIX}.submission_attempt")
      if @health_care_application.short_form?
        StatsD.increment("#{HCA::Service::STATSD_KEY_PREFIX}.submission_attempt_short_form")
      end
    end

    def skip_sentry_exception_types
      super + [Common::Exceptions::BackendServiceException]
    end
  end
end
