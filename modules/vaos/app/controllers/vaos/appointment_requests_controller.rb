# frozen_string_literal: true

require_dependency 'vaos/application_controller'

module VAOS
  class AppointmentRequestsController < ApplicationController
    before_action :validate_params, only: :index

    MASSASSIGN_PARAMS_PUT = %i[
      email phone_number option_date1 option_time1 option_date2 option_time2 option_date3 option_time3
      status appointment_type visit_type text_messaging_allowed phone_number purpose_of_visit
      other_purpose_of_visit purpose_of_visit provider_id second_request second_request_submitted
      provider_name requested_phone_call type_of_care_id has_veteran_new_message has_provider_new_message
      provider_seen_appointment_request requested_phone_call type_of_care_id created_date last_access_date
      last_updated_date facility patient best_timeto_call appointment_request_detail_code
    ].freeze

    MASSASSIGN_PARAMS_POST = MASSASSIGN_PARAMS_PUT - %i[created_date last_access_date last_updated_date]

    def index
      response = appointment_requests_service.get_requests(start_date, end_date)
      render json: AppointmentRequestsSerializer.new(response[:data], meta: response[:meta])
    end

    def create
      response = appointment_requests_service.post_request params.permit(*MASSASSIGN_PARAMS_POST)
      render json: AppointmentRequestsSerializer.new(response[:data]), status: :created
    end

    def update
      response = appointment_requests_service.put_request(id, params.permit(*MASSASSIGN_PARAMS_PUT))
      render json: AppointmentRequestsSerializer.new(response[:data])
    end

    private

    def id
      params.require(:id)
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
