# frozen_string_literal: true

require 'hca/service'
require 'bgs/service'
require 'pdf_fill/filler'
require 'lighthouse/facilities/v1/client'

module V0
  class HealthCareApplicationsController < ApplicationController
    include IgnoreNotFound
    include RetriableConcern

    service_tag 'healthcare-application'
    FORM_ID = '1010ez'

    skip_before_action(:authenticate, only: %i[create show enrollment_status healthcheck facilities download_pdf])

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

    def show
      application = HealthCareApplication.find(params[:id])
      render json: HealthCareApplicationSerializer.new(application)
    end

    def create
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
      import_facilities_if_empty
      facilities = HealthFacility.where(postal_name: params[:state])
      render json: facilities.map { |facility| { id: facility.station_number, name: facility.name } }
    end

    def download_pdf
      file_name = SecureRandom.uuid
      source_file_path = with_retries('Generate 10-10EZ PDF') do
        PdfFill::Filler.fill_form(health_care_application, file_name)
      end

      client_file_name = file_name_for_pdf(health_care_application.parsed_form)
      file_contents    = File.read(source_file_path)

      send_data file_contents, filename: client_file_name, type: 'application/pdf', disposition: 'attachment'
    ensure
      File.delete(source_file_path) if source_file_path && File.exist?(source_file_path)
    end

    private

    def file_name_for_pdf(parsed_form)
      veteran_name = parsed_form.try(:[], 'veteranFullName')
      first_name = veteran_name.try(:[], 'first') || 'First'
      last_name = veteran_name.try(:[], 'last') || 'Last'
      "10-10EZ_#{first_name}_#{last_name}.pdf"
    end

    def health_care_application
      @health_care_application ||= HealthCareApplication.new(params.permit(:form))
    end

    def import_facilities_if_empty
      HCA::StdInstitutionImportJob.new.perform unless HealthFacility.exists?
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
