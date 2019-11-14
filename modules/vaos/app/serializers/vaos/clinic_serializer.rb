# frozen_string_literal: true

require 'fast_jsonapi'

module VAOS
  class ClinicSerializer
    include FastJsonapi::ObjectSerializer

    set_id :site_code
    attributes :site_code,
               :clinic_id,
               :clinic_name,
               :clinic_friendly_location_name,
               :primary_stop_code,
               :secondary_stop_code,
               :direct_scheduling_flag,
               :display_to_patient_flag,
               :institution_name,
               :institution_code,
               :object_type,
               :link
  end
end
