# frozen_string_literal: true

module VAOS
  class AppointmentRequestsController < VAOS::BaseController
    before_action :validate_params, only: :index

    BASE_REQUIRED_PARAMS = %i[
      option_date1 option_time1 option_date2 option_time2 option_date3 option_time3 appointment_type visit_type
      phone_number facility
    ].freeze

    BASE_PARAMS_WHITELIST = [
      :type, :option_date1, :option_time1, :option_date2, :option_time2, :option_date3, :option_time3, :status,
      :appointment_type, :visit_type, :phone_number, :email, :purpose_of_visit, :other_purpose_of_visit,
      :provider_id, :provider_name, :second_request, :second_request_submitted, :requested_phone_call, :type_of_care_id,
      :additional_information, :address, :city, :state, :zip_code, :distance_willing_to_travel, :new_message,
      :office_hours, :preferred_city, :preferred_state, :preferred_zip_code, :provider_option, :preferred_language,
      :reason_for_visit, :service, best_timeto_call: [], appointment_request_detail_code: [], preferred_providers: [
        :id, :first_name, :last_name, :practice_name, :provider_street, :provider_city, :provider_state,
        :provider_zip_code1, address: %i[street city state zip_code]
      ], facility: [
        :name, :type, :facility_code, :state, :city, :address, :parent_site_code, :supports_v_a_r,
        children: %i[name type facility_code state city address parent_site_code]
      ], patient: %i[inpatient text_messaging_allowed]
    ].freeze

    def index
      response = appointment_requests_service.get_requests(start_date, end_date)
      render json: AppointmentRequestsSerializer.new(response[:data], meta: response[:meta])
    end

    def create
      response = appointment_requests_service.post_request(params_for_create)
      render json: AppointmentRequestsSerializer.new(response[:data]), status: :created
    end

    def update
      response = appointment_requests_service.put_request(id, params_for_update)
      render json: AppointmentRequestsSerializer.new(response[:data])
    end

    private

    def id
      params.require(:id)
    end

    def params_for_update
      params.require(BASE_REQUIRED_PARAMS + [:created_date])
      params[:facility].require(%i[name facility_code parent_site_code])
      params.permit(*(BASE_PARAMS_WHITELIST + [:created_date]))
    end

    def params_for_create
      params.require(BASE_REQUIRED_PARAMS)
      params[:facility].require(%i[name facility_code parent_site_code])
      params.permit(*BASE_PARAMS_WHITELIST)
    end

    def appointment_requests_service
      VAOS::AppointmentRequestsService.for_user(current_user)
    end

    def validate_params
      raise Common::Exceptions::ParameterMissing, 'start_date' if params[:start_date].blank?
      raise Common::Exceptions::ParameterMissing, 'end_date' if params[:end_date].blank?
    end

    def start_date
      Date.parse(params[:start_date])
    rescue ArgumentError
      raise Common::Exceptions::InvalidFieldValue.new('start_date', params[:start_date])
    end

    def end_date
      Date.parse(params[:end_date])
    rescue ArgumentError
      raise Common::Exceptions::InvalidFieldValue.new('end_date', params[:end_date])
    end
  end
end
