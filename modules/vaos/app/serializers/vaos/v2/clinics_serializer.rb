# frozen_string_literal: true

require 'fast_jsonapi'

module VAOS
  module V2
    class ClinicSerializer
      include FastJsonapi::ObjectSerializer

      set_id :id

      set_type :clinics
      
      attributes :vista_site,
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