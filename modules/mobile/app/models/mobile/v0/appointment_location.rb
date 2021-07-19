# frozen_string_literal: true

require 'common/models/resource'

module Mobile
  module V0
    # Child model of Mobile::V0::Appointment to all location (VA facility) related data
    #
    # @example create a new instance and parse incoming data
    #   Mobile::V0::Adapters::AppointmentLocation.new(location_hash)
    #
    class AppointmentLocation < Common::Resource
      attribute :name, Types::String
      attribute :address, AppointmentAddress
      attribute :lat, Types::Float.optional
      attribute :long, Types::Float.optional
      attribute :phone, AppointmentPhone.optional
      attribute :url, Types::String.optional
      attribute :code, Types::String.optional
    end
  end
end
