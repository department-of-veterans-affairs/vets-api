# frozen_string_literal: true

require 'common/models/resource'

module VAOS
  # class DateTimeMdy < Common::Resource
  #   def coerce(value)
  #     DateTime.strptime(value, '%m/%d/%Y %H:%M:%S')
  #   end
  # end

  class AppointmentTimeSlot < Common::Resource
    attribute :start_date_time, Types::DateTime
    attribute :end_date_time, Types::DateTime
    attribute :booking_status, Types::String
    attribute :remaining_allowed_over_bookings, Types::String
    attribute :availability, Types::Bool
  end
end
