# frozen_string_literal: true

require 'common/models/resource'

module VAOS
  class FacilityAvailability < Common::Resource
    attribute :clinic_id, Types::Coercible::String
    attribute :clinic_name, Types::Coercible::String
    attribute :appointment_length, Types::Coercible::Integer
    attribute :clinic_display_start_time, Types::Coercible::String
    attribute :display_increments, Types::Coercible::String
    attribute :stop_code, Types::Coercible::String
    attribute :ask_for_check_in, Types::Bool
    attribute :max_overbooks_per_day, Types::Coercible::Integer
    attribute :has_user_access_to_clinic, Types::Bool
    attribute :primary_stop_code, Types::Coercible::String
    attribute :secondary_stop_code, Types::Coercible::String
    attribute :list_size, Types::Coercible::Integer
    attribute :empty, Types::Bool
    attribute :appointment_time_slot, Types::Array.of(VAOS::AppointmentTimeSlot)
  end
end
