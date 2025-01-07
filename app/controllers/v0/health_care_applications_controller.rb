# frozen_string_literal: true

require 'hca/service'
require 'bgs/service'
require 'pdf_fill/filler'
require 'lighthouse/facilities/v1/client'

module V0
  class HealthCareApplicationsController < ApplicationController
    include IgnoreNotFound

    service_tag 'healthcare-application'
    FORM_ID = '1010ez'

    skip_before_action(:authenticate, only: %i[create show enrollment_status healthcheck facilities])

    before_action :record_submission_attempt, only: :create
    before_action :load_user, only: %i[create enrollment_status]
    before_action(only: :rating_info) { authorize(:hca_disability_rating, :access?) }

    def rating_info
      if Flipper.enabled?(:hca_disable_bgs_service)
        # Return 0 when not calling the actual BGS::Service
        render json: HCARatingInfoSerializer.new({ user_percent_of_disability: 0 })
        return
      end

      service = BGS::Service.new(current_user)
      disability_rating = service.find_rating_data[:disability_rating_record][:service_connected_combined_degree]

      hca_rating_info = { user_percent_of_disability: disability_rating }
      render json: HCARatingInfoSerializer.new(hca_rating_info)
    end

    def create
      health_care_application.async_compatible = params[:async_all]
      health_care_application.google_analytics_client_id = params[:ga_client_id]
      health_care_application.user = current_user

      begin
        result = health_care_application.process!
      rescue HCA::SOAPParser::ValidationError
        raise Common::Exceptions::BackendServiceException.new('HCA422', status: 422)
      end

      clear_saved_form(FORM_ID)

      if result[:id]
        render json: HealthCareApplicationSerializer.new(result)
      else
        render json: result
      end
    end

    def show
      application = HealthCareApplication.find(params[:id])
      render json: HealthCareApplicationSerializer.new(application)
    end

    def enrollment_status
      loa3 = current_user&.loa3?

      icn =
        if loa3
          current_user.icn
        else
          Sentry.set_extras(user_loa: current_user&.loa)
          HealthCareApplication.user_icn(HealthCareApplication.user_attributes(params[:userAttributes]))
        end

      raise Common::Exceptions::RecordNotFound, nil if icn.blank?

      render(json: HealthCareApplication.enrollment_status(icn, loa3))
    end

    def healthcheck
      render(json: HCA::Service.new.health_check)
    end

    def facilities
      lighthouse_facilities = lighthouse_facilities_service.get_facilities(lighthouse_facilities_params)

      render(json: active_facilities(lighthouse_facilities))
    end

    private

    def active_facilities(lighthouse_facilities)
      active_ids = active_ves_facility_ids
      lighthouse_facilities.select { |facility| active_ids.include?(facility.unique_id) }
    end

    def active_ves_facility_ids
      ids = cached_ves_facility_ids

      return ids if ids.any?
      return ids if Flipper.enabled?(:hca_retrieve_facilities_without_repopulating)

      HCA::StdInstitutionImportJob.new.perform

      cached_ves_facility_ids
    end

    def cached_ves_facility_ids
      StdInstitutionFacility.active.pluck(:station_number).compact
    end

    def health_care_application
      @health_care_application ||= HealthCareApplication.new(params.permit(:form))
    end

    def lighthouse_facilities_service
      @lighthouse_facilities_service ||= Lighthouse::Facilities::V1::Client.new
    end

    def lighthouse_facilities_params
      params.except(:format).permit(
        :zip,
        :state,
        :lat,
        :long,
        :radius,
        :bbox,
        :visn,
        :type,
        :services,
        :mobile,
        :page,
        :per_page,
        facilityIds: []
      )
    end

    def record_submission_attempt
      StatsD.increment("#{HCA::Service::STATSD_KEY_PREFIX}.submission_attempt")
      if health_care_application.short_form?
        StatsD.increment("#{HCA::Service::STATSD_KEY_PREFIX}.submission_attempt_short_form")
      end
    end

    def skip_sentry_exception_types
      super + [Common::Exceptions::BackendServiceException]
    end
  end
end
