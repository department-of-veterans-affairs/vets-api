# frozen_string_literal: true

require 'common/models/base'

module VAOS
  class FacilityAvailability < Common::Base
    attribute :clinic_id, String
    attribute :clinic_name, String
    attribute :appointment_length, Integer
    attribute :clinic_display_start_time, String
    attribute :display_increments, String
    attribute :stop_code, String
    attribute :ask_for_check_in, Boolean
    attribute :max_overbooks_per_day, Integer
    attribute :has_user_access_to_clinic, Boolean
    attribute :primary_stop_code, String
    attribute :secondary_stop_code, String
    attribute :list_size, Integer
    attribute :empty, Boolean
    attribute :appointment_time_slot, Array[VAOS::AppointmentTimeSlot]
  end
end
