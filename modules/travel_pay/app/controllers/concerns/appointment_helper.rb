# frozen_string_literal: true

module AppointmentHelper
  extend ActiveSupport::Concern

  def find_or_create_appt_id!(claim_type, params = {})
    Rails.logger.info(message: "#{claim_type} claim: Get appt by date time: #{params['appointment_date_time']}")
    appt = appts_service.find_or_create_appointment(params)

    if appt.nil? || appt[:data].nil?
      msg = "No appointment found for #{params['appointment_date_time']}"
      Rails.logger.error(message: msg)
      raise Common::Exceptions::ResourceNotFound, detail: msg
    end

    appt[:data]['id']
  end

  private

  def auth_manager
    @auth_manager ||= TravelPay::AuthManager.new(Settings.travel_pay.client_number, @current_user)
  end

  def appts_service
    @appts_service ||= TravelPay::AppointmentsService.new(auth_manager)
  end
end
