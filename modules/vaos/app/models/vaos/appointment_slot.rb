# frozen_string_literal: true

require 'common/models/resource'

module VAOS
  class AppointmentSlot < Common::Resource
    transform_types do |type|
      case type.name
      when :start_date_time || :end_date_time
        type.constructor do |value|
          DateTime.strptime(value, '%m/%d/%Y %H:%M:%S')
        end
      else
        type
      end
    end

    attribute :start_date_time, Types::DateTime
    attribute :end_date_time, Types::DateTime
    attribute :booking_status, Types::String
    attribute :remaining_allowed_over_bookings, Types::String
    attribute :availability, Types::Bool
  end
end
