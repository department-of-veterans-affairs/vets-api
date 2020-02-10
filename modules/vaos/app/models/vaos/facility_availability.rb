# frozen_string_literal: true

require 'common/models/resource'

module VAOS
  class FacilityAvailability < Common::Resource
    attribute :clinic_id, Types::String
    attribute :clinic_name, Types::String
    attribute :appointment_length, Types::Integer
    attribute :clinic_display_start_time, Types::String
    attribute :display_increments, Types::String
    attribute :stop_code, Types::String
    attribute :ask_for_check_in, Types::Bool
    attribute :max_overbooks_per_day, Types::Integer
    attribute :has_user_access_to_clinic, Types::Bool
    attribute :primary_stop_code, Types::String
    attribute :secondary_stop_code, Types::String
    attribute :list_size, Types::Integer
    attribute :empty, Types::Bool
    attribute :appointment_time_slot, Types::Array.of(VAOS::AppointmentTimeSlot)
  end
end
