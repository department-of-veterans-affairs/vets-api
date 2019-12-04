# frozen_string_literal: true

require 'common/models/resource'

module VAOS
  class DateTimeMdy < Virtus::Attribute
    def coerce(value)
      DateTime.strptime(value, '%m/%d/%Y %H:%M:%S')
    end
  end

  class AppointmentTimeSlot < Common::Base
    attribute :start_date_time, VAOS::DateTimeMdy
    attribute :end_date_time, VAOS::DateTimeMdy
    attribute :booking_status, String
    attribute :remaining_allowed_over_bookings, String
    attribute :availability, Boolean
  end
end
