# frozen_string_literal: true

# VAOS V0 routes and controllers no longer in use
# :nocov:
require 'fast_jsonapi'

module VAOS
  module V0
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
                 :object_type
    end
  end
end
# :nocov:
