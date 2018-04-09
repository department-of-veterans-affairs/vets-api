# frozen_string_literal: true

require 'vsopdf/vso_appointment_form'

module V0
  class VsoAppointmentsController < ApplicationController
    include ActionController::ParamsWrapper

    wrap_parameters VsoAppointment, format: :json

    def appt_params
      params.permit(VsoAppointment.attribute_set.map(&:name))
    end

    def create
      appt = VsoAppointment.new(appt_params)
      raise Common::Exceptions::ParameterMissing, appt.errors.messages.keys.first.to_s unless appt.valid?

      form = VsoAppointmentForm.new appt
      resp = form.send_pdf

      if resp.status == 200
        render json: { "message": 'submitted' }
      else
        render json: { "message": 'error', "details": resp.body }, status: resp.status
      end
    end
  end
end
