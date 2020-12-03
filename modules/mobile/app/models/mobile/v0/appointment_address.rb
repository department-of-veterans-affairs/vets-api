# frozen_string_literal: true

require 'common/models/resource'

module Mobile
  module V0
    # Child model of Mobile::V0::AppointmentLocation to store address data
    #
    # @example create a new instance and parse incoming data
    #   Mobile::V0::Adapters::AppointmentAddress.new(address_hash)
    #
    class AppointmentAddress < Common::Resource
      attribute :street, Types::String
      attribute :city, Types::String
      attribute :state, Types::String
      attribute :zip_code, Types::String
    end
  end
end
