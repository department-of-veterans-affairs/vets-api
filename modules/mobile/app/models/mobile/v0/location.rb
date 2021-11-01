# frozen_string_literal: true

require 'common/models/resource'

module Mobile
  module V0
    # @example create a new instance and parse incoming data
    #   Mobile::V0::Adapters::Location.new(location_hash)
    #
    class Location < Common::Resource
      attribute :id, Types::String.optional
      attribute :name, Types::String
      attribute :address, Address
      attribute :lat, Types::Float.optional
      attribute :long, Types::Float.optional
      attribute :phone, AppointmentPhone.optional
      attribute :url, Types::String.optional
      attribute :code, Types::String.optional
    end
  end
end
