# frozen_string_literal: true

StatsD.logger = Logger.new 'log/statsd.log' if Rails.env.development?

vaos_endpoints = %w[get_appointment get_appointments get_available_slots get_cancel_reasons get_clinic_institutions
                    get_direct_booking_elig_crit get_eligibility get_facilities get_facilities_limits get_facility
                    get_facility_available_appointments get_facility_clinics get_facility_limits get_facility_visits
                    get_messages get_patient_appointment_metadata get_preferences get_provider get_request get_requests
                    get_request_eligibility_criteria get_scheduling_configurations get_supported_sites
                    get_system_facilities get_system_pact get_systems post_appointment post_message post_request
                    put_cancel_appointment put_preferences put_request update_appointment]

Rails.application.reloader.to_prepare do
  vaos_endpoints.each do |endpoint|
    StatsD.increment("api.vaos.#{endpoint}.total", 0)
    StatsD.increment("api.vaos.#{endpoint}.fail", 0)
  end
end

StatsD.increment('api.vaos.va_mobile.response.total', 0)
StatsD.increment('api.vaos.va_mobile.response.fail', 0)
