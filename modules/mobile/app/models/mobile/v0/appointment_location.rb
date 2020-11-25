# frozen_string_literal: true

require 'common/models/resource'

module Mobile
  module V0
    class AppointmentLocation < Common::Resource
      attribute :name, Types::String
      attribute :address, AppointmentAddress
      attribute :phone, AppointmentPhone
      attribute :url, Types::String.optional
      attribute :code, Types::String.optional
    end
  end
end
