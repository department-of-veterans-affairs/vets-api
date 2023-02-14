# frozen_string_literal: true

# VAOS V0 routes and controllers no longer in use
# :nocov:
require 'fast_jsonapi'

module VAOS
  module V0
    class AvailabilitySerializer
      include FastJsonapi::ObjectSerializer

      set_id :clinic_id
      attributes :clinic_id,
                 :clinic_name,
                 :appointment_length,
                 :clinic_display_start_time,
                 :display_increments,
                 :stop_code,
                 :ask_for_check_in,
                 :max_overbooks_per_day,
                 :has_user_access_to_clinic,
                 :primary_stop_code,
                 :secondary_stop_code,
                 :list_size,
                 :empty,
                 :appointment_time_slot
    end
  end
end
# :nocov:
