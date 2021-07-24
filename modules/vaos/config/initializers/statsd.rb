# frozen_string_literal: true

vaos_endpoints = %w[get_appointments get_cancel_reasons get_clinic_institutions get_clinic_institutions
                    get_eligibility get_facilities get_facility_available_appointments get_facility_clinics
                    get_facility_limits get_facility_visits get_messages get_preferences get_requests
                    get_supported_sites get_system_facilities post_appointment post_message post_request
                    put_cancel_appointment put_preferences put_request]

Rails.application.reloader.to_prepare do
  vaos_endpoints.each do |endpoint|
    StatsD.increment("api.vaos.#{endpoint}.total", 0)
    StatsD.increment("api.vaos.#{endpoint}.fail", 0)
  end
end

StatsD.increment('api.vaos.va_mobile.response.total', 0)
StatsD.increment('api.vaos.va_mobile.response.fail', 0)
