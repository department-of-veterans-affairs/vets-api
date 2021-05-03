# frozen_string_literal: true

module VAOS
  module V2
    class ClinicsSerializer
      include FastJsonapi::ObjectSerializer

      set_id :vista_site

      set_type :clinics

      attributes :id,
                 :service_name,
                 :physical_location,
                 :phone_number,
                 :station_id,
                 :station_name,
                 :primary_stop_code,
                 :primary_stop_code_name,
                 :secondary_stop_code,
                 :secondary_stop_code_name,
                 :patient_direct_scheduling,
                 :patient_display,
                 :char4
    end
  end
end
