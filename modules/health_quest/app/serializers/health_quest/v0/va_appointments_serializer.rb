# frozen_string_literal: true

module HealthQuest
  module V0
    class VAAppointmentsSerializer
      include FastJsonapi::ObjectSerializer

      set_id do |object|
        Digest::MD5.hexdigest(object.start_date)
      end

      set_type :va_appointments

      attributes :start_date, :sta6aid, :clinic_id, :clinic_friendly_name, :facility_id, :community_care

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
