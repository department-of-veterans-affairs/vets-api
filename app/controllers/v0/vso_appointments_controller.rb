# frozen_string_literal: true

require 'vso_pdf/vso_appointment_form'

module V0
  class VSOAppointmentsController < ApplicationController
    include ActionController::ParamsWrapper

    wrap_parameters VSOAppointment, format: :json

    def appt_params
      params.permit(VSOAppointment.attribute_set.map(&:name) + [
        veteran_full_name: %i[first middle last suffix],
        claimant_full_name: %i[first middle last suffix],
        claimant_address: %i[street street2 city country state postal_code]
      ])
    end

    def create
      appt = VSOAppointment.new(appt_params)
      raise Common::Exceptions::ParameterMissing, appt.errors.messages.keys.first.to_s unless appt.valid?

      form = VSOAppointmentForm.new appt
      resp = form.send_pdf

      if resp.status == 200
        render json: { "message": 'submitted' }
      else
        render json: { "message": 'error', "details": resp.body }, status: resp.status
      end
    end
  end
end
