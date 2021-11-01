# frozen_string_literal: true

require 'common/models/resource'

module Mobile
  module V0
    # Child model of Mobile::V0::Location to store phone data
    #
    # @example create a new instance and parse incoming data
    #   Mobile::V0::Adapters::AppointmentPhone.new(phone_hash)
    #
    class AppointmentPhone < Common::Resource
      attribute :area_code, Types::String.optional
      attribute :number, Types::String.optional
      attribute :extension, Types::String.optional
    end
  end
end
