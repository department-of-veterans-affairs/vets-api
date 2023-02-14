# frozen_string_literal: true

# VAOS V0 routes and controllers no longer in use
# :nocov:
module VAOS
  module V0
    class VAAppointmentsSerializer
      include FastJsonapi::ObjectSerializer

      set_id :id

      set_type :va_appointments

      attributes :char4,
                 :clinic_id,
                 :clinic_friendly_name,
                 :community_care,
                 :facility_id,
                 :phone_only,
                 :start_date,
                 :sta6aid

      attribute :vds_appointments do |object|
        Array.wrap(object&.vds_appointments).map do |vds|
          vds.except(:patient_id)                                       # remove patient identifiers
             .reverse_merge(booking_note: nil, appointment_length: nil) # make array consistent
        end
      end

      attribute :vvs_appointments do |object|
        Array.wrap(object&.vvs_appointments).map do |vvs|
          vvs.merge( # flatten the structure of patients and providers and remove patient identifiers
            patients: vvs.dig(:patients, :patient).to_a.map { |patient| patient.except(:id) },
            providers: vvs.dig(:providers, :provider).to_a.map { |provider| provider.except(:id) }
          )
        end
      end
    end
  end
end
# :nocov:
