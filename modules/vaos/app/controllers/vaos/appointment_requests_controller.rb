# frozen_string_literal: true

require_dependency 'vaos/application_controller'

module VAOS
  class AppointmentRequestsController < ApplicationController
    before_action :validate_params

    def index
      render json: AppointmentRequestsSerializer.new(requests[:data], meta: requests[:meta])
    end

    private

    def appointment_requests_service
      VAOS::AppointmentRequestsService.for_user(current_user)
    end

    def requests
      @requests ||=
        appointment_requests_service.get_requests(start_date, end_date, pagination_params)
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
